from fastapi import APIRouter, Depends, status

from app.core.deps import require_academy_scope, require_role
from app.models import Batch, User, UserRole
from app.schemas import BatchCreate, BatchOut

router = APIRouter(prefix="/batches", tags=["batches"])


@router.get("", response_model=list[BatchOut])
async def list_batches(
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    _current_user, academy_id = scope
    batches = await Batch.find(
        Batch.academy_id == academy_id,
        Batch.is_active == True,  # noqa: E712
    ).to_list()
    return sorted(batches, key=lambda b: b.name)


@router.post("", response_model=BatchOut, status_code=status.HTTP_201_CREATED)
async def create_batch(
    payload: BatchCreate,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    batch = Batch(
        academy_id=current_user.academy_id,
        coach_id=current_user.id if current_user.role == UserRole.coach else None,
        name=payload.name,
        level=payload.level,
        schedule_days=payload.schedule_days,
        start_time=payload.start_time,
        end_time=payload.end_time,
    )
    await batch.insert()
    return batch
