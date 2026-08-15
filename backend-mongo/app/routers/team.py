import secrets

from fastapi import APIRouter, Depends, status

from app.core.deps import require_role
from app.core.security import hash_password
from app.models import User, UserRole
from app.schemas import CoachCreate, UserOut

router = APIRouter(prefix="/academy/team", tags=["team"])


@router.get("", response_model=list[UserOut])
async def list_team(
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    return await User.find(
        User.academy_id == current_user.academy_id,
        User.role == UserRole.coach,
    ).to_list()


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_coach(
    payload: CoachCreate,
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
    await coach.insert()
    return coach
