from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import require_academy_scope, require_role
from app.db import get_db
from app.models import Parent, Student, User, UserRole, Batch
from app.schemas import StudentCreate, StudentUpdate, StudentOut

router = APIRouter(prefix="/students", tags=["students"])


def _to_out(student: Student, db: Session = None) -> StudentOut:
    batch_name = None
    if student.batch_id and db:
        b = db.query(Batch).filter(Batch.id == student.batch_id).first()
        batch_name = b.name if b else None

    return StudentOut(
        id=student.id,
        student_number=student.student_number,
        name=student.name,
        level=student.level,
        batch_id=student.batch_id,
        batch_name=batch_name,
        is_active=student.is_active,
        default_fee=student.default_fee,
        parent_name=student.parent.name if student.parent else None,
        parent_phone=student.parent.phone if student.parent else None,
        parent_email=student.parent.email if student.parent else None,
        parent_address=student.parent.address if student.parent else None,
    )


@router.get("", response_model=list[StudentOut])
def list_students(
    include_inactive: bool = False,
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    """Scoped to the caller's own academy - or, for Super Admin, to
    whichever academy_id they pass. include_inactive=true also returns
    deactivated/past students, for a 'past students' view."""
    _current_user, academy_id = scope
    query = db.query(Student).filter(Student.academy_id == academy_id)
    if not include_inactive:
        query = query.filter(Student.is_active.is_(True))
    return [_to_out(s, db=db) for s in query.order_by(Student.name).all()]


@router.post("", response_model=StudentOut, status_code=status.HTTP_201_CREATED)
def create_student(
    payload: StudentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    parent = None
    if payload.parent_phone:
        parent = (
            db.query(Parent)
            .filter(Parent.academy_id == current_user.academy_id, Parent.phone == payload.parent_phone)
            .first()
        )
    if not parent and payload.parent_name and payload.parent_phone:
        parent = Parent(
            academy_id=current_user.academy_id,
            name=payload.parent_name,
            phone=payload.parent_phone,
            alternate_phone=payload.parent_alternate_phone,
            email=payload.parent_email,
            address=payload.parent_address,
        )
        db.add(parent)
        db.flush()

    existing_count = (
        db.query(Student).filter(Student.academy_id == current_user.academy_id).count()
    )

    student = Student(
        academy_id=current_user.academy_id,
        parent_id=parent.id if parent else None,
        batch_id=payload.batch_id,
        student_number=existing_count + 1,
        name=payload.name,
        date_of_birth=payload.date_of_birth,
        level=payload.level,
        default_fee=payload.default_fee,
    )
    db.add(student)
    db.commit()
    db.refresh(student)
    return _to_out(student, db=db)


@router.patch("/{student_id}", response_model=StudentOut)
def update_student(
    student_id: str,
    payload: StudentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    student = (
        db.query(Student)
        .filter(Student.id == student_id, Student.academy_id == current_user.academy_id)
        .first()
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    changes = payload.model_dump(exclude_unset=True)
    
    # Handle parent updates
    parent_changes = {}
    for key in ['parent_name', 'parent_phone', 'parent_email', 'parent_address']:
        if key in changes:
            parent_changes[key.replace('parent_', '')] = changes.pop(key)
            
    if parent_changes and student.parent:
        for k, v in parent_changes.items():
            setattr(student.parent, k, v)
    elif parent_changes and not student.parent:
        parent = Parent(
            academy_id=current_user.academy_id,
            name=parent_changes.get('name', 'Unknown'),
            phone=parent_changes.get('phone', 'Unknown'),
            email=parent_changes.get('email'),
            address=parent_changes.get('address'),
        )
        db.add(parent)
        db.flush()
        student.parent_id = parent.id

    # Handle student updates
    for field, value in changes.items():
        setattr(student, field, value)

    db.commit()
    db.refresh(student)
    return _to_out(student, db=db)


@router.delete("/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student(
    student_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Soft delete / deactivate student."""
    student = (
        db.query(Student)
        .filter(Student.id == student_id, Student.academy_id == current_user.academy_id)
        .first()
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    student.is_active = False
    db.commit()


@router.delete("/{student_id}/permanent", status_code=status.HTTP_204_NO_CONTENT)
def hard_delete_student(
    student_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Permanently delete student record and associated attendance/payment entries."""
    student = (
        db.query(Student)
        .filter(Student.id == student_id, Student.academy_id == current_user.academy_id)
        .first()
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    from app.models import Attendance, Payment, TournamentRegistration
    db.query(Attendance).filter(Attendance.student_id == student_id).delete(synchronize_session=False)
    db.query(Payment).filter(Payment.student_id == student_id).delete(synchronize_session=False)
    db.query(TournamentRegistration).filter(TournamentRegistration.student_id == student_id).delete(synchronize_session=False)
    db.delete(student)
    db.commit()
