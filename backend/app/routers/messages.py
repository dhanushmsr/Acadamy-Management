from datetime import datetime
from typing import List

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.db import SessionLocal, get_db
from app.integrations.whatsapp import WhatsAppSendError, send_whatsapp_text_via_template
from app.models import Broadcast, BroadcastRecipient, RecipientStatus, Student, User, UserRole
from app.schemas import BroadcastCreate, BroadcastDetailOut, BroadcastOut

router = APIRouter(prefix="/messages", tags=["messages"])


def _send_one(recipient_id: str, phone: str, body: str) -> None:
    """Runs in the background with its own DB session - the request's
    session is already closed by the time this executes. One HTTP call
    per recipient; failures are recorded per-recipient rather than
    failing the whole broadcast."""
    db = SessionLocal()
    try:
        recipient = db.query(BroadcastRecipient).filter(BroadcastRecipient.id == recipient_id).first()
        if not recipient:
            return
        try:
            provider_id = send_whatsapp_text_via_template(phone, body)
            recipient.status = RecipientStatus.sent
            recipient.provider_message_id = provider_id
            recipient.sent_at = datetime.utcnow()
        except WhatsAppSendError as e:
            recipient.status = RecipientStatus.failed
            recipient.error_message = str(e)
        db.commit()
    finally:
        db.close()


@router.post("/broadcast", response_model=BroadcastOut, status_code=status.HTTP_201_CREATED)
def create_broadcast(
    payload: BroadcastCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Either pass student_ids for specific students, or send_to_all=true
    for everyone active in the academy. The HTTP response comes back as
    soon as the broadcast + recipient rows are saved - the actual
    WhatsApp calls happen afterward in the background so sending to a
    few hundred parents doesn't time out the request."""
    if not current_user.academy_id:
        raise HTTPException(status_code=400, detail="This account is not tied to an academy")

    query = db.query(Student).filter(
        Student.academy_id == current_user.academy_id,
        Student.is_active.is_(True),
    )
    if not payload.send_to_all:
        if not payload.student_ids:
            raise HTTPException(status_code=400, detail="Provide student_ids or set send_to_all=true")
        query = query.filter(Student.id.in_(payload.student_ids))
    students = query.all()

    recipients_data = [(s.id, s.parent.phone) for s in students if s.parent and s.parent.phone]
    if not recipients_data:
        raise HTTPException(
            status_code=400,
            detail="None of the selected students have a parent phone number on file",
        )

    broadcast = Broadcast(
        academy_id=current_user.academy_id,
        created_by=current_user.id,
        message_type=payload.message_type,
        body=payload.body,
    )
    db.add(broadcast)
    db.flush()  # populates broadcast.id before we attach recipients

    recipient_ids_and_phones = []
    for student_id, phone in recipients_data:
        recipient = BroadcastRecipient(broadcast_id=broadcast.id, student_id=student_id, phone=phone)
        db.add(recipient)
        db.flush()  # populates recipient.id
        recipient_ids_and_phones.append((recipient.id, phone))

    db.commit()
    db.refresh(broadcast)

    for recipient_id, phone in recipient_ids_and_phones:
        background_tasks.add_task(_send_one, recipient_id, phone, broadcast.body)

    return broadcast


@router.get("/broadcasts", response_model=List[BroadcastOut])
def list_broadcasts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Message history for the academy - what was sent, and when."""
    return (
        db.query(Broadcast)
        .filter(Broadcast.academy_id == current_user.academy_id)
        .order_by(Broadcast.created_at.desc())
        .all()
    )


@router.get("/broadcasts/{broadcast_id}", response_model=BroadcastDetailOut)
def get_broadcast(
    broadcast_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Per-recipient delivery status - did it actually reach everyone."""
    broadcast = (
        db.query(Broadcast)
        .filter(Broadcast.id == broadcast_id, Broadcast.academy_id == current_user.academy_id)
        .first()
    )
    if not broadcast:
        raise HTTPException(status_code=404, detail="Broadcast not found")
    return broadcast
