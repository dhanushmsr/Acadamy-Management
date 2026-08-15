import secrets

import shutil
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session

from app.core.deps import require_role, get_current_user
from app.core.security import hash_password
from app.db import get_db
from app.models import Academy, AcademyStatus, AuditLog, Student, User, UserRole
from app.schemas import AcademyCreate, AcademyCreatedOut, AcademyOut, AcademyUpdate, PasswordResetPayload

router = APIRouter(prefix="/academies", tags=["academies"])


@router.get("", response_model=list[AcademyOut])
def list_academies(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academies = db.query(Academy).filter(Academy.status != AcademyStatus.deleted).all()
    result = []
    for academy in academies:
        out = AcademyOut.model_validate(academy)
        out.student_count = (
            db.query(Student)
            .filter(Student.academy_id == academy.id, Student.is_active.is_(True))
            .count()
        )
        result.append(out)
    return result


@router.get("/{academy_id}", response_model=AcademyOut)
def get_academy(
    academy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.super_admin and str(current_user.academy_id) != str(academy_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not have permission to perform this action")
        
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    out = AcademyOut.model_validate(academy)
    out.student_count = (
        db.query(Student)
        .filter(Student.academy_id == academy.id, Student.is_active.is_(True))
        .count()
    )
    return out


@router.post("", response_model=AcademyCreatedOut, status_code=status.HTTP_201_CREATED)
def create_academy(
    payload: AcademyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    # Check if admin email already exists
    existing_user = db.query(User).filter(User.email == payload.admin_email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="An account with this admin email already exists. Please use a different email.")

    academy = Academy(
        name=payload.name,
        category=payload.category,
        address=payload.address,
        logo_url=payload.logo_url,
        phone=payload.phone,
        email=payload.email,
        tagline=payload.tagline,
        created_by=current_user.id,
    )
    db.add(academy)
    db.flush()  # populates academy.id before we attach the admin user to it

    admin_user = User(
        name=payload.admin_name,
        email=payload.admin_email,
        hashed_password=hash_password(payload.admin_password),
        role=UserRole.academy_admin,
        academy_id=academy.id,
    )
    db.add(admin_user)
    db.commit()
    db.refresh(academy)

    out = AcademyCreatedOut.model_validate(academy)
    return out


@router.patch("/{academy_id}", response_model=AcademyOut)
def update_academy(
    academy_id: str,
    payload: AcademyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_role(UserRole.super_admin, UserRole.academy_admin)
    ),
):
    """Academy admins can edit their own profile; every changed field is
    written to AuditLog so the super admin can see what changed and when."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")

    if current_user.role == UserRole.academy_admin and current_user.academy_id != academy_id:
        raise HTTPException(status_code=403, detail="Not your academy")

    changes = payload.model_dump(exclude_unset=True)
    for field, new_value in changes.items():
        old_value = getattr(academy, field)
        if old_value != new_value:
            db.add(
                AuditLog(
                    entity_type="academy",
                    entity_id=academy.id,
                    field_name=field,
                    old_value=str(old_value),
                    new_value=str(new_value),
                    changed_by=current_user.id,
                )
            )
            setattr(academy, field, new_value)

    db.commit()
    db.refresh(academy)
    return academy


@router.post("/{academy_id}/suspend", response_model=AcademyOut)
def suspend_academy(
    academy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    academy.status = AcademyStatus.suspended
    db.query(User).filter(User.academy_id == academy_id).update({"is_active": False})
    db.commit()
    db.refresh(academy)
    return academy


@router.post("/{academy_id}/activate", response_model=AcademyOut)
def activate_academy(
    academy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    academy.status = AcademyStatus.active
    db.query(User).filter(User.academy_id == academy_id).update({"is_active": True})
    db.commit()
    db.refresh(academy)
    return academy


@router.delete("/{academy_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_academy(
    academy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    """Soft delete: flips status rather than removing the row, so
    historical student/billing records under this academy stay intact."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")
    academy.status = AcademyStatus.deleted
    db.commit()


@router.post("/{academy_id}/logo", response_model=AcademyOut)
def upload_logo(
    academy_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.super_admin)),
):
    import os
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")

    if current_user.role == UserRole.academy_admin and current_user.academy_id != academy_id:
        raise HTTPException(status_code=403, detail="Not your academy")

    os.makedirs("static/logos", exist_ok=True)
    file_path = f"static/logos/{academy_id}_{file.filename}"
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    academy.logo_url = f"/{file_path}"
    db.commit()
    db.refresh(academy)
    return academy


@router.delete("/{academy_id}/logo", response_model=AcademyOut)
def delete_logo(
    academy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.super_admin)),
):
    import os
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")

    if current_user.role == UserRole.academy_admin and current_user.academy_id != academy_id:
        raise HTTPException(status_code=403, detail="Not your academy")

    if academy.logo_url:
        relative_path = academy.logo_url.lstrip("/")
        if os.path.exists(relative_path):
            try:
                os.remove(relative_path)
            except Exception:
                pass
        academy.logo_url = None
        db.commit()
        db.refresh(academy)
    return academy


@router.post("/{academy_id}/reset-password")
def reset_academy_password(
    academy_id: str,
    payload: PasswordResetPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")

    admin_user = (
        db.query(User)
        .filter(User.academy_id == academy_id, User.role == UserRole.academy_admin)
        .first()
    )
    if not admin_user:
        admin_user = db.query(User).filter(User.academy_id == academy_id).first()

    if not admin_user:
        raise HTTPException(status_code=404, detail="No user account found for this academy")

    if len(payload.new_password.strip()) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters long")

    admin_user.hashed_password = hash_password(payload.new_password.strip())
    db.commit()
    return {"message": f"Password reset successfully for {admin_user.email}"}

