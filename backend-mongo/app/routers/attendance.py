from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.deps import require_academy_scope, require_role
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
    status: str


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
    status: str


class CalendarDayOut(BaseModel):
    date: str
    students_present: int
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
async def get_day_attendance(
    date: str,
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    day_start, day_end = _day_bounds(date)
    _current_user, academy_id = scope

    holiday = await Holiday.find_one(
        Holiday.academy_id == academy_id,
        Holiday.date == day_start,
    )

    batches = await Batch.find(
        Batch.academy_id == academy_id,
        Batch.is_active == True,  # noqa: E712
    ).to_list()

    rows = []
    for batch in batches:
        students = await Student.find(
            Student.batch_id == batch.id,
            Student.is_active == True,  # noqa: E712
        ).to_list()
        session = await ClassSession.find_one(
            ClassSession.batch_id == batch.id,
            ClassSession.scheduled_at >= day_start,
            ClassSession.scheduled_at < day_end,
        )
        marks = {}
        if session:
            for a in await Attendance.find(Attendance.class_session_id == session.id).to_list():
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
async def mark_attendance(
    payload: AttendanceMarkRequest,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Get-or-creates the ClassSession for this batch+date, then upserts
    the one student's mark - no separate 'schedule a session' step."""
    day_start, day_end = _day_bounds(payload.date)

    session = await ClassSession.find_one(
        ClassSession.batch_id == payload.batch_id,
        ClassSession.scheduled_at >= day_start,
        ClassSession.scheduled_at < day_end,
    )
    if not session:
        session = ClassSession(batch_id=payload.batch_id, scheduled_at=day_start)
        await session.insert()

    mark = await Attendance.find_one(
        Attendance.class_session_id == session.id,
        Attendance.student_id == payload.student_id,
    )
    status_enum = AttendanceStatus.present if payload.status == "present" else AttendanceStatus.absent
    if mark:
        mark.status = status_enum
        mark.marked_by = current_user.id
        mark.marked_at = datetime.utcnow()
        await mark.save()
    else:
        await Attendance(
            class_session_id=session.id,
            student_id=payload.student_id,
            status=status_enum,
            marked_by=current_user.id,
        ).insert()
    return {"status": "ok"}


@router.get("/calendar", response_model=List[CalendarDayOut])
async def get_calendar(
    year: int,
    month: int,
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    """Per-day summary for one calendar month. Every call is scoped to
    the year/month requested, so 'this month's attendance' is always
    exactly that - no separate reset step needed."""
    month_start = datetime(year, month, 1)
    month_end = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)
    _current_user, academy_id = scope

    holidays = {
        h.date.date()
        for h in await Holiday.find(
            Holiday.academy_id == academy_id,
            Holiday.date >= month_start,
            Holiday.date < month_end,
        ).to_list()
    }

    batches = await Batch.find(Batch.academy_id == academy_id).to_list()
    batch_ids = [b.id for b in batches]

    sessions = (
        await ClassSession.find(
            ClassSession.batch_id.in_(batch_ids),
            ClassSession.scheduled_at >= month_start,
            ClassSession.scheduled_at < month_end,
        ).to_list()
        if batch_ids
        else []
    )
    session_day_by_id = {s.id: s.scheduled_at.date() for s in sessions}

    present_counts = {}
    if sessions:
        marks = await Attendance.find(
            Attendance.class_session_id.in_(list(session_day_by_id.keys())),
            Attendance.status == AttendanceStatus.present,
        ).to_list()
        for a in marks:
            day = session_day_by_id.get(a.class_session_id)
            if day:
                present_counts[day] = present_counts.get(day, 0) + 1

    days = []
    current = month_start
    while current < month_end:
        d = current.date()
        days.append(
            CalendarDayOut(
                date=d.isoformat(),
                students_present=present_counts.get(d, 0),
                is_holiday=d in holidays,
            )
        )
        current += timedelta(days=1)
    return days


@router.post("/holidays", response_model=HolidayOut, status_code=status.HTTP_201_CREATED)
async def create_holiday(
    payload: HolidayCreate,
    current_user: User = Depends(require_role(UserRole.academy_admin)),
):
    day_start, _ = _day_bounds(payload.date)
    holiday = Holiday(academy_id=current_user.academy_id, date=day_start, reason=payload.reason)
    await holiday.insert()
    return HolidayOut(id=holiday.id, date=payload.date, reason=holiday.reason)


@router.delete("/holidays/{holiday_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_holiday(
    holiday_id: str,
    current_user: User = Depends(require_role(UserRole.academy_admin)),
):
    holiday = await Holiday.get(holiday_id)
    if not holiday or holiday.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Holiday not found")
    await holiday.delete()


@router.get("/students/{student_id}/attendance", response_model=StudentAttendanceSummaryOut)
async def get_student_attendance(
    student_id: str,
    year: int,
    month: int,
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    """Days present/absent for ONE month - reads as 'this month's
    attendance' with no leftover data from prior months."""
    _current_user, academy_id = scope
    student = await Student.get(student_id)
    if not student or student.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Student not found")

    month_start = datetime(year, month, 1)
    month_end = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)

    batches = await Batch.find(Batch.academy_id == academy_id).to_list()
    batch_ids = [b.id for b in batches]
    sessions = (
        await ClassSession.find(
            ClassSession.batch_id.in_(batch_ids),
            ClassSession.scheduled_at >= month_start,
            ClassSession.scheduled_at < month_end,
        ).to_list()
        if batch_ids
        else []
    )
    session_ids = [s.id for s in sessions]

    marks = (
        await Attendance.find(
            Attendance.student_id == student_id,
            Attendance.class_session_id.in_(session_ids),
        ).to_list()
        if session_ids
        else []
    )
    present = sum(1 for m in marks if m.status == AttendanceStatus.present)
    absent = sum(1 for m in marks if m.status == AttendanceStatus.absent)

    return StudentAttendanceSummaryOut(
        year=year, month=month, days_present=present, days_absent=absent, total_marked=present + absent
    )
