from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import require_academy_scope, require_role
from app.models import Parent, Student, User, UserRole
from app.schemas import StudentCreate, StudentOut, StudentUpdate

router = APIRouter(prefix="/students", tags=["students"])


@router.get("", response_model=list[StudentOut])
async def list_students(
    include_inactive: bool = False,
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    """Scoped to the caller's own academy - or, for Super Admin, to
    whichever academy_id they pass. include_inactive=true also returns
    deactivated/past students, for a 'past students' view.

    The one real difference from the Postgres version: parent_name and
    parent_phone used to come for free from a SQLAlchemy relationship().
    Mongo has no join, so parents are fetched in one batch query and
    stitched together in Python instead of one lookup per student."""
    _current_user, academy_id = scope
    if include_inactive:
        students = await Student.find(Student.academy_id == academy_id).to_list()
    else:
        students = await Student.find(
            Student.academy_id == academy_id,
            Student.is_active == True,  # noqa: E712 - Beanie query builder, not a bool check
        ).to_list()

    parent_ids = [s.parent_id for s in students if s.parent_id]
    parents_by_id = {}
    if parent_ids:
        parents = await Parent.find(Parent.id.in_(parent_ids)).to_list()
        parents_by_id = {p.id: p for p in parents}

    def to_out(s: Student) -> StudentOut:
        p = parents_by_id.get(s.parent_id)
        return StudentOut(
            id=s.id,
            student_number=s.student_number,
            name=s.name,
            level=s.level,
            batch_id=s.batch_id,
            is_active=s.is_active,
            parent_name=p.name if p else None,
            parent_phone=p.phone if p else None,
            parent_email=p.email if p else None,
        )

    return [to_out(s) for s in sorted(students, key=lambda s: s.name)]


@router.post("", response_model=StudentOut, status_code=status.HTTP_201_CREATED)
async def create_student(
    payload: StudentCreate,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """If parent_phone matches an existing parent in this academy, the
    student is linked to them. Otherwise a new Parent document is
    created from the parent_* fields."""
    parent = None
    if payload.parent_phone:
        parent = await Parent.find_one(
            Parent.academy_id == current_user.academy_id,
            Parent.phone == payload.parent_phone,
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
        await parent.insert()

    existing_count = await Student.find(Student.academy_id == current_user.academy_id).count()

    student = Student(
        academy_id=current_user.academy_id,
        parent_id=parent.id if parent else None,
        batch_id=payload.batch_id,
        student_number=existing_count + 1,
        name=payload.name,
        date_of_birth=payload.date_of_birth,
        level=payload.level,
    )
    await student.insert()

    return StudentOut(
        id=student.id,
        student_number=student.student_number,
        name=student.name,
        level=student.level,
        batch_id=student.batch_id,
        is_active=student.is_active,
        parent_name=parent.name if parent else None,
        parent_phone=parent.phone if parent else None,
        parent_email=parent.email if parent else None,
    )


@router.patch("/{student_id}", response_model=StudentOut)
async def update_student(
    student_id: str,
    payload: StudentUpdate,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    student = await Student.get(student_id)
    if not student or student.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Student not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(student, field, value)
    await student.save()

    parent = await Parent.get(student.parent_id) if student.parent_id else None
    return StudentOut(
        id=student.id,
        student_number=student.student_number,
        name=student.name,
        level=student.level,
        batch_id=student.batch_id,
        is_active=student.is_active,
        parent_name=parent.name if parent else None,
        parent_phone=parent.phone if parent else None,
        parent_email=parent.email if parent else None,
    )


@router.delete("/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student(
    student_id: str,
    current_user: User = Depends(require_role(UserRole.academy_admin)),
):
    """Soft delete - deactivates rather than removing, so past
    attendance/payment history stays intact."""
    student = await Student.get(student_id)
    if not student or student.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Student not found")
    student.is_active = False
    await student.save()
