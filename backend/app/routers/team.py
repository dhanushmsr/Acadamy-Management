import secrets

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.core.security import hash_password
from app.db import get_db
from app.models import User, UserRole
from app.schemas import CoachCreate, UserOut

router = APIRouter(prefix="/academy/team", tags=["team"])


@router.get("", response_model=list[UserOut])
def list_team(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    return (
        db.query(User)
        .filter(User.academy_id == current_user.academy_id, User.role == UserRole.coach)
        .all()
    )


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_coach(
    payload: CoachCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin)),
):
    """Scoped automatically to the caller's academy - academy_id isn't
    something the client can set here, unlike the platform Super
    Admin's /users endpoint."""
    temp_password = secrets.token_urlsafe(10)
    coach = User(
        name=payload.name,
        email=payload.email,
        role=UserRole.coach,
        academy_id=current_user.academy_id,
        hashed_password=hash_password(temp_password),
    )
    db.add(coach)
    db.commit()
    db.refresh(coach)
    return coach
