from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.deps import require_academy_scope, require_role
from app.db import get_db
from app.models import (
    Attendance,
    AttendanceStatus,
    Batch,
    ClassSession,
    Holiday,
    Student,
    User,
    UserRole,
)

router = APIRouter(tags=["attendance"])


def _day_bounds(date_str: str):
    day = datetime.strptime(date_str, "%Y-%m-%d")
    return day, day + timedelta(days=1)


# ---- schemas (local to this router - only used here) ----

class StudentAttendanceMark(BaseModel):
    student_id: str
    name: str
    status: str  # "present" / "absent" / "unmarked"


class BatchAttendanceOut(BaseModel):
    batch_id: str
    batch_name: str
    students: List[StudentAttendanceMark]


class DayAttendanceOut(BaseModel):
    date: str
    is_holiday: bool
    batches: List[BatchAttendanceOut]


class AttendanceMarkRequest(BaseModel):
    batch_id: str
    date: str
    student_id: str
    status: str  # "present" or "absent"


class CalendarDayOut(BaseModel):
    date: str
    students_present: int = 0
    students_absent: int = 0
    students_unmarked: int = 0
    is_holiday: bool


class HolidayCreate(BaseModel):
    date: str
    reason: Optional[str] = None


class HolidayOut(BaseModel):
    id: str
    date: str
    reason: Optional[str] = None


class StudentAttendanceSummaryOut(BaseModel):
    year: int
    month: int
    days_present: int
    days_absent: int
    total_marked: int


# ---- endpoints ----

@router.get("/attendance/day", response_model=DayAttendanceOut)
def get_day_attendance(
    date: str,
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    day_start, day_end = _day_bounds(date)
    _current_user, academy_id = scope

    holiday = (
        db.query(Holiday)
        .filter(Holiday.academy_id == academy_id, Holiday.date == day_start)
        .first()
    )

    batches = (
        db.query(Batch)
        .filter(Batch.academy_id == academy_id, Batch.is_active.is_(True))
        .all()
    )

    rows = []
    for batch in batches:
        students = (
            db.query(Student)
            .filter(Student.batch_id == batch.id, Student.is_active.is_(True))
            .all()
        )
        session = (
            db.query(ClassSession)
            .filter(
                ClassSession.batch_id == batch.id,
                ClassSession.scheduled_at >= day_start,
                ClassSession.scheduled_at < day_end,
            )
            .first()
        )
        marks = {}
        if session:
            for a in db.query(Attendance).filter(Attendance.class_session_id == session.id):
                marks[a.student_id] = a.status.value

        rows.append(
            BatchAttendanceOut(
                batch_id=batch.id,
                batch_name=batch.name,
                students=[
                    StudentAttendanceMark(
                        student_id=s.id, name=s.name, status=marks.get(s.id, "unmarked")
                    )
                    for s in students
                ],
            )
        )

    return DayAttendanceOut(date=date, is_holiday=bool(holiday), batches=rows)


@router.post("/attendance/mark")
def mark_attendance(
    payload: AttendanceMarkRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Get-or-creates the ClassSession for this batch+date, then upserts
    the one student's mark - no separate 'schedule a session' step
    needed, matching how the original app's Mark Attendance screen
    worked directly off a batch."""
    day_start, day_end = _day_bounds(payload.date)

    session = (
        db.query(ClassSession)
        .filter(
            ClassSession.batch_id == payload.batch_id,
            ClassSession.scheduled_at >= day_start,
            ClassSession.scheduled_at < day_end,
        )
        .first()
    )
    if not session:
        session = ClassSession(batch_id=payload.batch_id, scheduled_at=day_start)
        db.add(session)
        db.flush()

    mark = (
        db.query(Attendance)
        .filter(
            Attendance.class_session_id == session.id,
            Attendance.student_id == payload.student_id,
        )
        .first()
    )
    status_enum = AttendanceStatus.present if payload.status == "present" else AttendanceStatus.absent
    if mark:
        mark.status = status_enum
        mark.marked_by = current_user.id
        mark.marked_at = datetime.utcnow()
    else:
        db.add(
            Attendance(
                class_session_id=session.id,
                student_id=payload.student_id,
                status=status_enum,
                marked_by=current_user.id,
            )
        )
    db.commit()
    return {"status": "ok"}


@router.get("/calendar", response_model=List[CalendarDayOut])
def get_calendar(
    year: int,
    month: int,
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    """Per-day summary for one calendar month - powers the manager's
    calendar view. Every call is scoped to the year/month asked for, so
    'this month's attendance' is always exactly that; there's no
    separate reset step because nothing accumulates past a month
    boundary in the first place."""
    month_start = datetime(year, month, 1)
    month_end = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)
    _current_user, academy_id = scope

    holidays = {
        h.date.date()
        for h in db.query(Holiday).filter(
            Holiday.academy_id == academy_id,
            Holiday.date >= month_start,
            Holiday.date < month_end,
        )
    }

    batch_ids = [
        b.id for b in db.query(Batch).filter(Batch.academy_id == academy_id)
    ]
    sessions = (
        db.query(ClassSession)
        .filter(
            ClassSession.batch_id.in_(batch_ids),
            ClassSession.scheduled_at >= month_start,
            ClassSession.scheduled_at < month_end,
        )
        .all()
        if batch_ids
        else []
    )
    session_day_by_id = {s.id: s.scheduled_at.date() for s in sessions}

    present_counts = {}
    absent_counts = {}
    if sessions:
        for a in db.query(Attendance).filter(
            Attendance.class_session_id.in_(list(session_day_by_id.keys())),
        ):
            day = session_day_by_id.get(a.class_session_id)
            if day:
                if a.status == AttendanceStatus.present:
                    present_counts[day] = present_counts.get(day, 0) + 1
                elif a.status == AttendanceStatus.absent:
                    absent_counts[day] = absent_counts.get(day, 0) + 1

    total_active_students = db.query(Student).filter(
        Student.academy_id == academy_id,
        Student.is_active == True
    ).count()

    days = []
    current = month_start
    while current < month_end:
        d = current.date()
        p = present_counts.get(d, 0)
        ab = absent_counts.get(d, 0)
        unmarked = max(0, total_active_students - p - ab) if (p > 0 or ab > 0) else 0

        days.append(
            CalendarDayOut(
                date=d.isoformat(),
                students_present=p,
                students_absent=ab,
                students_unmarked=unmarked,
                is_holiday=d in holidays,
            )
        )
        current += timedelta(days=1)
    return days


@router.post("/holidays", response_model=HolidayOut, status_code=status.HTTP_201_CREATED)
def create_holiday(
    payload: HolidayCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin)),
):
    day_start, _ = _day_bounds(payload.date)
    holiday = Holiday(academy_id=current_user.academy_id, date=day_start, reason=payload.reason)
    db.add(holiday)
    db.commit()
    db.refresh(holiday)
    return HolidayOut(id=holiday.id, date=payload.date, reason=holiday.reason)


@router.delete("/holidays/{holiday_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_holiday(
    holiday_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin)),
):
    holiday = (
        db.query(Holiday)
        .filter(Holiday.id == holiday_id, Holiday.academy_id == current_user.academy_id)
        .first()
    )
    if not holiday:
        raise HTTPException(status_code=404, detail="Holiday not found")
    db.delete(holiday)
    db.commit()


@router.get("/students/{student_id}/attendance", response_model=StudentAttendanceSummaryOut)
def get_student_attendance(
    student_id: str,
    year: int,
    month: int,
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    """Days present/absent for ONE month - the student profile calls
    this with the current year/month, so it always reads as 'this
    month's attendance' with no leftover data from prior months."""
    _current_user, academy_id = scope
    student = (
        db.query(Student)
        .filter(Student.id == student_id, Student.academy_id == academy_id)
        .first()
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    month_start = datetime(year, month, 1)
    month_end = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)

    session_ids = [
        s.id
        for s in db.query(ClassSession)
        .join(Batch, ClassSession.batch_id == Batch.id)
        .filter(
            Batch.academy_id == academy_id,
            ClassSession.scheduled_at >= month_start,
            ClassSession.scheduled_at < month_end,
        )
    ]
    marks = (
        db.query(Attendance)
        .filter(Attendance.student_id == student_id, Attendance.class_session_id.in_(session_ids))
        .all()
        if session_ids
        else []
    )
    present = sum(1 for m in marks if m.status == AttendanceStatus.present)
    marked_absent = sum(1 for m in marks if m.status == AttendanceStatus.absent)

    now = datetime.utcnow()
    # Find total sessions scheduled up to now for this student's batch
    total_class_sessions = 0
    if student.batch_id:
        total_class_sessions = db.query(ClassSession).filter(
            ClassSession.batch_id == student.batch_id,
            ClassSession.scheduled_at >= month_start,
            ClassSession.scheduled_at < month_end,
            ClassSession.scheduled_at <= now,
        ).count()

    # Unmarked days automatically count as absent
    total_expected = max(len(session_ids), total_class_sessions)
    effective_absent = max(marked_absent, total_expected - present)

    return StudentAttendanceSummaryOut(
        year=year, month=month, days_present=present, days_absent=effective_absent, total_marked=total_expected
    )
