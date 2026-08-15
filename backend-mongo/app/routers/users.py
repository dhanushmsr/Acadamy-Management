import secrets

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import require_role
from app.core.security import hash_password
from app.models import User, UserRole
from app.schemas import UserCreate, UserOut

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserOut])
async def list_users(
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    return await User.find(User.role != UserRole.super_admin).to_list()


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreate,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    if payload.role not in (UserRole.academy_admin, UserRole.coach):
        raise HTTPException(
            status_code=400,
            detail="Super admin creates academy_admin/coach accounts only - "
            "student and parent logins are created from within the academy "
            "(alongside their Student/Parent record), not here.",
        )
    temp_password = secrets.token_urlsafe(10)
    user = User(
        name=payload.name,
        email=payload.email,
        role=payload.role,
        academy_id=payload.academy_id,
        hashed_password=hash_password(temp_password),
    )
    await user.insert()
    return user


@router.post("/{user_id}/enable", response_model=UserOut)
async def enable_user(
    user_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = True
    await user.save()
    return user


@router.post("/{user_id}/disable", response_model=UserOut)
async def disable_user(
    user_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    await user.save()
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: str,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    """Soft delete keeps attendance/billing history intact."""
    user = await User.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    await user.save()
