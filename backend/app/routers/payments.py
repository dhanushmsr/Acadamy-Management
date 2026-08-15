from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import require_academy_scope, require_role
from app.db import get_db
from app.integrations.email import EmailSendError, render_invoice_html, send_email
from app.models import Academy, Batch, Payment, PaymentStatus, Student, User, UserRole
from app.schemas import PaymentCreate, PaymentOut, PaymentStatusUpdate

router = APIRouter(prefix="/payments", tags=["payments"])


def _to_out(payment: Payment, student_name: Optional[str] = None) -> PaymentOut:
    return PaymentOut(
        id=payment.id,
        student_id=payment.student_id,
        student_name=student_name,
        plan_type=payment.plan_type,
        amount=payment.amount,
        amount_paid=payment.amount_paid,
        status=payment.status,
        due_date=payment.due_date,
        paid_at=payment.paid_at,
        invoice_number=payment.invoice_number,
    )


@router.get("", response_model=list[PaymentOut])
def list_payments(
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    _current_user, academy_id = scope
    students = {
        s.id: s.name
        for s in db.query(Student).filter(Student.academy_id == academy_id)
    }
    if not students:
        return []
    payments = (
        db.query(Payment)
        .filter(Payment.student_id.in_(students.keys()))
        .order_by(Payment.due_date.desc())
        .all()
    )
    return [_to_out(p, students.get(p.student_id)) for p in payments]


@router.post("", response_model=PaymentOut, status_code=status.HTTP_201_CREATED)
def create_payment(
    payload: PaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    student = (
        db.query(Student)
        .filter(Student.id == payload.student_id, Student.academy_id == current_user.academy_id)
        .first()
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    payment = Payment(
        student_id=payload.student_id,
        plan_type=payload.plan_type,
        amount=payload.amount,
        due_date=payload.due_date,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return _to_out(payment, student.name)


@router.patch("/{payment_id}/status", response_model=PaymentOut)
def update_payment_status(
    payment_id: str,
    payload: PaymentStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Manager sets the status by hand - unpaid / partial / paid, no
    payment gateway involved anywhere. The receipt email only fires the
    moment status *transitions into* fully paid, not on every save, so
    re-opening a paid record later doesn't re-send a receipt."""
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    student = db.query(Student).filter(Student.id == payment.student_id).first()
    if not student or student.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Payment not found")

    was_paid = payment.status == PaymentStatus.paid

    if payload.status == PaymentStatus.unpaid:
        payment.amount_paid = 0
    elif payload.status == PaymentStatus.partial:
        payment.amount_paid = (
            payload.amount_paid if payload.amount_paid is not None else payment.amount_paid
        )
    elif payload.status == PaymentStatus.paid:
        payment.amount_paid = payment.amount

    payment.status = payload.status
    db.commit()
    db.refresh(payment)

    if payload.status == PaymentStatus.paid and not was_paid:
        academy = db.query(Academy).filter(Academy.id == current_user.academy_id).first()
        batch = db.query(Batch).filter(Batch.id == student.batch_id).first() if student.batch_id else None
        coach = db.query(User).filter(User.id == batch.coach_id).first() if batch and batch.coach_id else None
        parent = student.parent

        payment.paid_at = datetime.utcnow()
        payment.invoice_number = f"INV-{academy.id[:4].upper()}-{int(payment.paid_at.timestamp())}"
        db.commit()
        db.refresh(payment)

        recipient = (parent.email if parent and parent.email else None) or getattr(student, 'email', None)
        if recipient:
            try:
                html = render_invoice_html(
                    academy_name=academy.name,
                    academy_tagline=academy.tagline,
                    academy_logo_url=academy.logo_url,
                    academy_address=academy.address,
                    academy_phone=academy.phone,
                    academy_email=academy.email,
                    invoice_number=payment.invoice_number,
                    issue_date=payment.paid_at.strftime("%B %d, %Y"),
                    due_date=payment.due_date.strftime("%B %d, %Y") if payment.due_date else "-",
                    student_name=student.name,
                    student_number=f"PER-{str(student.student_number or 0).zfill(6)}",
                    batch_name=batch.name if batch else "-",
                    coach_name=coach.name if coach else "-",
                    billing_period=payment.paid_at.strftime("%B %Y"),
                    amount=payment.amount,
                    status="paid",
                    amount_paid=payment.amount,
                )
                send_email(
                    to_email=recipient,
                    subject=f"Payment Receipt - {academy.name}",
                    html_body=html,
                )
            except EmailSendError:
                pass

    return _to_out(payment, student.name)


@router.post("/{payment_id}/send-email")
def send_payment_invoice_email(
    payment_id: str,
    target_email: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    student = db.query(Student).filter(Student.id == payment.student_id).first()
    if not student or student.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Payment not found")

    academy = db.query(Academy).filter(Academy.id == current_user.academy_id).first()
    batch = db.query(Batch).filter(Batch.id == student.batch_id).first() if student.batch_id else None
    coach = db.query(User).filter(User.id == batch.coach_id).first() if batch and batch.coach_id else None
    parent = student.parent

    student_email = getattr(student, 'email', None)
    parent_email = parent.email if parent and parent.email else None
    to_addr = target_email or parent_email or student_email

    if not to_addr:
        raise HTTPException(
            status_code=400,
            detail="No email address found for this student or parent. Please update their profile with an email address.",
        )

    if not payment.invoice_number:
        payment.invoice_number = f"INV-{academy.id[:4].upper()}-{int(datetime.utcnow().timestamp())}"
        db.commit()

    logo_url = academy.logo_url
    if logo_url and not logo_url.startswith("http"):
        logo_url = f"http://127.0.0.1:8000{logo_url}"

    status_str = payment.status.value if hasattr(payment.status, 'value') else str(payment.status)
    html = render_invoice_html(
        academy_name=academy.name,
        academy_tagline=academy.tagline,
        academy_logo_url=logo_url,
        academy_address=academy.address,
        academy_phone=academy.phone,
        academy_email=academy.email,
        invoice_number=payment.invoice_number,
        issue_date=datetime.utcnow().strftime("%B %d, %Y"),
        due_date=payment.due_date.strftime("%B %d, %Y") if payment.due_date else "-",
        student_name=student.name,
        student_number=f"PER-{str(student.student_number or 0).zfill(6)}",
        batch_name=batch.name if batch else "General",
        coach_name=coach.name if coach else "N/A",
        billing_period=datetime.utcnow().strftime("%B %Y"),
        amount=payment.amount,
        status=status_str,
        amount_paid=payment.amount_paid or 0,
    )

    if status_str == "paid":
        subj = f"Payment Receipt #{payment.invoice_number} - {academy.name}"
    elif status_str == "partial":
        subj = f"Partial Payment Receipt #{payment.invoice_number} - {academy.name}"
    else:
        subj = f"Fee Payment Due Reminder #{payment.invoice_number} - {academy.name}"

    try:
        send_email(
            to_email=to_addr,
            subject=subj,
            html_body=html,
        )
        return {"message": f"Invoice email successfully sent to {to_addr}"}
    except EmailSendError as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")
