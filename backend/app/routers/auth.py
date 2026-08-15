from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import create_access_token, verify_password
from app.db import get_db
from app.models import User, UserRole
from app.schemas import LoginRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """One login for everyone. The client decides where to route the user
    based on the `role` in the response - see app_router.dart on the
    Flutter side."""
    user = db.query(User).filter(User.email == payload.email).first()

    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if user.role != UserRole.super_admin and user.academy_id:
        from app.models import Academy, AcademyStatus
        academy = db.query(Academy).filter(Academy.id == user.academy_id).first()
        if not academy or academy.status in [AcademyStatus.suspended, AcademyStatus.deleted]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is not accessible, contact owner",
            )
        if academy.status == AcademyStatus.active and not user.is_active:
            user.is_active = True
            db.commit()

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been disabled",
        )

    token = create_access_token(
        data={"sub": user.id, "role": user.role.value, "academy_id": user.academy_id}
    )
    return TokenResponse(access_token=token, role=user.role, academy_id=user.academy_id)
