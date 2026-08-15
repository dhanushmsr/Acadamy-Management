from datetime import datetime
from typing import List

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status

from app.core.deps import require_role
from app.integrations.whatsapp import WhatsAppSendError, send_whatsapp_text_via_template
from app.models import Broadcast, BroadcastRecipient, Parent, RecipientStatus, Student, User, UserRole
from app.schemas import BroadcastCreate, BroadcastDetailOut, BroadcastOut

router = APIRouter(prefix="/messages", tags=["messages"])


async def _send_one(broadcast_id: str, student_id: str, phone: str, body: str) -> None:
    """Runs in the background after the response has already gone out.
    Unlike the Postgres version, there's no separate recipient document
    to look up - recipients are embedded inside Broadcast, so this
    re-fetches the whole broadcast, finds the matching recipient by
    student_id, updates it in place, and saves the document back."""
    broadcast = await Broadcast.get(broadcast_id)
    if not broadcast:
        return

    for recipient in broadcast.recipients:
        if recipient.student_id == student_id:
            try:
                provider_id = send_whatsapp_text_via_template(phone, body)
                recipient.status = RecipientStatus.sent
                recipient.provider_message_id = provider_id
                recipient.sent_at = datetime.utcnow()
            except WhatsAppSendError as e:
                recipient.status = RecipientStatus.failed
                recipient.error_message = str(e)
            break

    await broadcast.save()


@router.post("/broadcast", response_model=BroadcastOut, status_code=status.HTTP_201_CREATED)
async def create_broadcast(
    payload: BroadcastCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Either pass student_ids for specific students, or send_to_all=true
    for everyone active in the academy. The HTTP response comes back as
    soon as the broadcast (with every recipient already embedded) is
    saved - the actual WhatsApp calls happen afterward in the
    background so sending to a few hundred parents doesn't time out
    the request."""
    if not current_user.academy_id:
        raise HTTPException(status_code=400, detail="This account is not tied to an academy")

    if payload.send_to_all:
        students = await Student.find(
            Student.academy_id == current_user.academy_id,
            Student.is_active == True,  # noqa: E712
        ).to_list()
    else:
        if not payload.student_ids:
            raise HTTPException(status_code=400, detail="Provide student_ids or set send_to_all=true")
        students = await Student.find(
            Student.academy_id == current_user.academy_id,
            Student.is_active == True,  # noqa: E712
            Student.id.in_(payload.student_ids),
        ).to_list()

    parent_ids = [s.parent_id for s in students if s.parent_id]
    parents_by_id = {}
    if parent_ids:
        parents = await Parent.find(Parent.id.in_(parent_ids)).to_list()
        parents_by_id = {p.id: p for p in parents}

    recipients_data = [
        (s.id, parents_by_id[s.parent_id].phone)
        for s in students
        if s.parent_id in parents_by_id and parents_by_id[s.parent_id].phone
    ]
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
        recipients=[
            BroadcastRecipient(student_id=student_id, phone=phone)
            for student_id, phone in recipients_data
        ],
    )
    await broadcast.insert()

    for student_id, phone in recipients_data:
        background_tasks.add_task(_send_one, broadcast.id, student_id, phone, broadcast.body)

    return broadcast


@router.get("/broadcasts", response_model=List[BroadcastOut])
async def list_broadcasts(
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Message history for the academy - what was sent, and when."""
    broadcasts = await Broadcast.find(Broadcast.academy_id == current_user.academy_id).to_list()
    return sorted(broadcasts, key=lambda b: b.created_at, reverse=True)


@router.get("/broadcasts/{broadcast_id}", response_model=BroadcastDetailOut)
async def get_broadcast(
    broadcast_id: str,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Per-recipient delivery status - did it actually reach everyone.
    Simpler than the Postgres version here: recipients are already
    embedded in the document, so there's no second query/join needed to
    assemble this response."""
    broadcast = await Broadcast.get(broadcast_id)
    if not broadcast or broadcast.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Broadcast not found")
    return broadcast
