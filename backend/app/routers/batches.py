from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.deps import require_academy_scope, require_role
from app.db import get_db
from app.models import Batch, User, UserRole
from app.schemas import BatchCreate, BatchOut

router = APIRouter(prefix="/batches", tags=["batches"])


@router.get("", response_model=list[BatchOut])
def list_batches(
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    _current_user, academy_id = scope
    return (
        db.query(Batch)
        .filter(Batch.academy_id == academy_id, Batch.is_active.is_(True))
        .order_by(Batch.name)
        .all()
    )


@router.post("", response_model=BatchOut, status_code=status.HTTP_201_CREATED)
def create_batch(
    payload: BatchCreate,
    db: Session = Depends(get_db),
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
    db.add(batch)
    db.commit()
    db.refresh(batch)
    return batch


@router.patch("/{batch_id}", response_model=BatchOut)
def update_batch(
    batch_id: str,
    payload: BatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    from fastapi import HTTPException
    batch = db.query(Batch).filter(Batch.id == batch_id, Batch.academy_id == current_user.academy_id).first()
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")

    batch.name = payload.name
    batch.level = payload.level
    batch.schedule_days = payload.schedule_days
    batch.start_time = payload.start_time
    batch.end_time = payload.end_time

    db.commit()
    db.refresh(batch)
    return batch

