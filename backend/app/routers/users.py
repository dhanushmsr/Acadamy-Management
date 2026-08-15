import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.core.security import hash_password
from app.db import get_db
from app.models import User, UserRole
from app.schemas import UserCreate, UserUpdate, UserOut

router = APIRouter(prefix="/users", tags=["users"])


from typing import Optional

@router.get("", response_model=list[UserOut])
def list_users(
    role: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    query = db.query(User)
    if role:
        query = query.filter(User.role == role)
    else:
        query = query.filter(User.role == UserRole.super_admin)
    return query.all()


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    temp_password = secrets.token_urlsafe(10)
    user = User(
        name=payload.name,
        email=payload.email,
        role=payload.role,
        academy_id=payload.academy_id,
        hashed_password=hash_password(temp_password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/enable", response_model=UserOut)
def enable_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = True
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/disable", response_model=UserOut)
def disable_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    """Soft delete keeps attendance/billing history intact."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    db.commit()


@router.patch("/{user_id}", response_model=UserOut)
def update_user(
    user_id: str,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if payload.name is not None:
        user.name = payload.name
    if payload.email is not None:
        user.email = payload.email
    if payload.phone is not None:
        user.phone = payload.phone
    if payload.password:
        user.hashed_password = hash_password(payload.password)
        
    db.commit()
    db.refresh(user)
    return user

