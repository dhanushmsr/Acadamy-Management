from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.db import get_db
from app.models import PlatformInvoice, PlatformInvoiceStatus, User, UserRole, Notification, NotificationType, Academy
from app.schemas import PlatformInvoiceCreate, PlatformInvoiceOut, PlatformInvoiceStatusUpdate

router = APIRouter(prefix="/platform-billing", tags=["platform-billing"])


@router.get("", response_model=list[PlatformInvoiceOut])
def list_invoices(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    invoices = db.query(PlatformInvoice).order_by(PlatformInvoice.created_at.desc()).all()
    out_list = []
    for inv in invoices:
        out = PlatformInvoiceOut.model_validate(inv)
        if inv.academy:
            out.academy_name = inv.academy.name
        out_list.append(out)
    return out_list


@router.post("", response_model=PlatformInvoiceOut, status_code=status.HTTP_201_CREATED)
def create_invoice(
    payload: PlatformInvoiceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    academy = db.query(Academy).filter(Academy.id == payload.academy_id).first()
    if not academy:
        raise HTTPException(status_code=404, detail="Academy not found")

    invoice = PlatformInvoice(
        academy_id=payload.academy_id,
        amount=payload.amount,
        due_date=payload.due_date,
        notes=payload.notes,
        status=PlatformInvoiceStatus.uncleared,
    )
    db.add(invoice)
    db.commit()
    db.refresh(invoice)
    
    out = PlatformInvoiceOut.model_validate(invoice)
    out.academy_name = academy.name
    return out


@router.patch("/{invoice_id}/status", response_model=PlatformInvoiceOut)
def update_invoice_status(
    invoice_id: str,
    payload: PlatformInvoiceStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    invoice = db.query(PlatformInvoice).filter(PlatformInvoice.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    invoice.status = payload.status
    if payload.status == PlatformInvoiceStatus.cleared and not invoice.cleared_at:
        invoice.cleared_at = datetime.utcnow()
    elif payload.status == PlatformInvoiceStatus.uncleared:
        invoice.cleared_at = None

    db.commit()
    db.refresh(invoice)

    out = PlatformInvoiceOut.model_validate(invoice)
    if invoice.academy:
        out.academy_name = invoice.academy.name
    return out


@router.post("/{invoice_id}/notify")
def send_invoice_notification(
    invoice_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    invoice = db.query(PlatformInvoice).filter(PlatformInvoice.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    admins = (
        db.query(User)
        .filter(User.academy_id == invoice.academy_id, User.role == UserRole.academy_admin)
        .all()
    )
    
    if not admins:
        raise HTTPException(status_code=404, detail="No academy admins found for this academy to notify")

    if invoice.status == PlatformInvoiceStatus.uncleared:
        title = "Platform Fee Due"
        body = f"A platform fee of ₹{invoice.amount} is due for your academy."
        n_type = NotificationType.fee_due
    else:
        title = "Platform Fee Cleared - Receipt"
        body = f"Your platform fee of ₹{invoice.amount} has been successfully cleared. Thank you!"
        n_type = NotificationType.fee_due

    for admin in admins:
        n = Notification(
            recipient_user_id=admin.id,
            type=n_type,
            title=title,
            body=body
        )
        db.add(n)

    db.commit()
    return {"message": f"Sent notification to {len(admins)} academy admins"}
