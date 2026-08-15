from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.db import get_db
from app.models import Notification, User, UserRole
from app.schemas import NotificationOut

router = APIRouter(prefix="/notifications", tags=["notifications"])

@router.get("", response_model=list[NotificationOut])
def get_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach, UserRole.student, UserRole.parent)),
):
    notifs = (
        db.query(Notification)
        .filter(Notification.recipient_user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )
    return notifs


@router.post("/{notification_id}/read", response_model=NotificationOut)
def mark_read(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach, UserRole.student, UserRole.parent)),
):
    notif = db.query(Notification).filter(Notification.id == notification_id, Notification.recipient_user_id == current_user.id).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif
