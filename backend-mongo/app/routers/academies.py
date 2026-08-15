import secrets

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import require_role
from app.core.security import hash_password
from app.models import Academy, AcademyStatus, AuditLog, Student, User, UserRole
from app.schemas import AcademyCreate, AcademyCreatedOut, AcademyOut, AcademyUpdate

router = APIRouter(prefix="/academies", tags=["academies"])


@router.get("", response_model=list[AcademyOut])
async def list_academies(
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academies = await Academy.find(Academy.status != AcademyStatus.deleted).to_list()
    result = []
    for academy in academies:
        out = AcademyOut.model_validate(academy)
        out.student_count = await Student.find(
            Student.academy_id == academy.id,
            Student.is_active == True,  # noqa: E712
        ).count()
        result.append(out)
    return result


@router.get("/{academy_id}", response_model=AcademyOut)
async def get_academy(
    academy_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = await Academy.get(academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    out = AcademyOut.model_validate(academy)
    out.student_count = await Student.find(
        Student.academy_id == academy.id,
        Student.is_active == True,  # noqa: E712
    ).count()
    return out


@router.post("", response_model=AcademyCreatedOut, status_code=status.HTTP_201_CREATED)
async def create_academy(
    payload: AcademyCreate,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    """Creates the academy AND its first academy-admin user - matches
    'I give the name, password, and address when creating their
    profile' from the brief. A random temp password is generated
    instead of you typing one, and returned ONCE in this response -
    copy it now, it isn't retrievable again (only its hash is stored).
    Wire up email delivery to replace this manual hand-off before going
    live."""
    academy = Academy(
        name=payload.name,
        address=payload.address,
        logo_url=payload.logo_url,
        phone=payload.phone,
        email=payload.email,
        tagline=payload.tagline,
        created_by=current_user.id,
    )
    await academy.insert()

    temp_password = secrets.token_urlsafe(10)
    admin_user = User(
        name=payload.admin_name,
        email=payload.admin_email,
        hashed_password=hash_password(temp_password),
        role=UserRole.academy_admin,
        academy_id=academy.id,
    )
    await admin_user.insert()

    out = AcademyCreatedOut.model_validate(academy)
    out.admin_temp_password = temp_password
    return out


@router.patch("/{academy_id}", response_model=AcademyOut)
async def update_academy(
    academy_id: str,
    payload: AcademyUpdate,
    current_user: User = Depends(
        require_role(UserRole.super_admin, UserRole.academy_admin)
    ),
):
    """Academy admins can edit their own profile; every changed field is
    written to AuditLog so the super admin can see what changed and
    when."""
    academy = await Academy.get(academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")

    if current_user.role == UserRole.academy_admin and current_user.academy_id != academy_id:
        raise HTTPException(status_code=403, detail="Not your academy")

    changes = payload.model_dump(exclude_unset=True)
    for field, new_value in changes.items():
        old_value = getattr(academy, field)
        if old_value != new_value:
            await AuditLog(
                entity_type="academy",
                entity_id=academy.id,
                field_name=field,
                old_value=str(old_value),
                new_value=str(new_value),
                changed_by=current_user.id,
            ).insert()
            setattr(academy, field, new_value)

    await academy.save()
    return academy


@router.post("/{academy_id}/suspend", response_model=AcademyOut)
async def suspend_academy(
    academy_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = await Academy.get(academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    academy.status = AcademyStatus.suspended
    await academy.save()
    return academy


@router.post("/{academy_id}/activate", response_model=AcademyOut)
async def activate_academy(
    academy_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = await Academy.get(academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    academy.status = AcademyStatus.active
    await academy.save()
    return academy


@router.delete("/{academy_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_academy(
    academy_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    """Soft delete: flips status rather than removing the document, so
    historical student/billing records under this academy stay intact."""
    academy = await Academy.get(academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    academy.status = AcademyStatus.deleted
    await academy.save()
