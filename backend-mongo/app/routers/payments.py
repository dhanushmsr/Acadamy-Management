from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import require_academy_scope, require_role
from app.integrations.email import EmailSendError, render_invoice_html, send_email
from app.models import Academy, Batch, Parent, Payment, PaymentStatus, Student, User, UserRole
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
async def list_payments(
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    _current_user, academy_id = scope
    students = await Student.find(Student.academy_id == academy_id).to_list()
    students_by_id = {s.id: s.name for s in students}
    if not students_by_id:
        return []
    payments = await Payment.find(Payment.student_id.in_(list(students_by_id.keys()))).to_list()
    return [_to_out(p, students_by_id.get(p.student_id)) for p in payments]


@router.post("", response_model=PaymentOut, status_code=status.HTTP_201_CREATED)
async def create_payment(
    payload: PaymentCreate,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    student = await Student.get(payload.student_id)
    if not student or student.academy_id != current_user.academy_id:
        raise HTTPException(status_code=404, detail="Student not found")

    payment = Payment(
        student_id=payload.student_id,
        plan_type=payload.plan_type,
        amount=payload.amount,
        due_date=payload.due_date,
    )
    await payment.insert()
    return _to_out(payment, student.name)


@router.patch("/{payment_id}/status", response_model=PaymentOut)
async def update_payment_status(
    payment_id: str,
    payload: PaymentStatusUpdate,
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    """Manager sets the status by hand - unpaid / partial / paid, no
    payment gateway involved anywhere. The receipt email only fires the
    moment status *transitions into* fully paid, not on every save."""
    payment = await Payment.get(payment_id)
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    student = await Student.get(payment.student_id)
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
    await payment.save()

    if payload.status == PaymentStatus.paid and not was_paid:
        academy = await Academy.get(current_user.academy_id)
        batch = await Batch.get(student.batch_id) if student.batch_id else None
        coach = await User.get(batch.coach_id) if batch and batch.coach_id else None
        parent = await Parent.get(student.parent_id) if student.parent_id else None

        payment.paid_at = datetime.utcnow()
        payment.invoice_number = f"INV-{academy.id[:4].upper()}-{int(payment.paid_at.timestamp())}"
        await payment.save()

        if parent and parent.email:
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
                )
                send_email(
                    to_email=parent.email,
                    subject=f"Payment Receipt - {academy.name}",
                    html_body=html,
                )
            except EmailSendError:
                pass

    return _to_out(payment, student.name)
