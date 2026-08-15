from fastapi import APIRouter, HTTPException, status

from app.core.security import create_access_token, verify_password
from app.models import User
from app.schemas import LoginRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest):
    """One login for everyone. The client decides where to route the user
    based on the `role` in the response - see app_router.dart on the
    Flutter side. Unchanged behavior from the Postgres version."""
    user = await User.find_one(User.email == payload.email)

    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been disabled",
        )

    token = create_access_token(
        data={"sub": user.id, "role": user.role.value, "academy_id": user.academy_id}
    )
    return TokenResponse(access_token=token, role=user.role, academy_id=user.academy_id)
