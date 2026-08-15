import logging
from datetime import datetime, date
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import require_role
from app.db import get_db
from app.models import Batch, Payment, Student, User, UserRole, Expense, Academy

router = APIRouter(prefix="/dashboard", tags=["dashboard"])
logger = logging.getLogger(__name__)


def _safe_date_fmt(dt_obj, fmt="%d %b %Y", fallback="Today"):
    if not dt_obj:
        return fallback
    if isinstance(dt_obj, (datetime, date)):
        return dt_obj.strftime(fmt)
    return str(dt_obj)


@router.get("-stats")
def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.super_admin, UserRole.academy_admin, UserRole.coach)),
):
    academy_id = current_user.academy_id
    if not academy_id and current_user.role == UserRole.super_admin:
        first_acad = db.query(Academy).first()
        academy_id = first_acad.id if first_acad else None

    if not academy_id:
        return {
            "current_date": datetime.now().isoformat(),
            "total_students": 0,
            "total_batches": 0,
            "upcoming_batches_today": 0,
            "total_income": 0,
            "outstanding_dues": 0,
            "academy_name": "Academy Workspace",
            "academy_address": "",
            "academy_phone": "",
            "academy_email": "",
            "academy_logo_url": None,
            "academy_category": "any",
            "todays_classes": [],
            "recent_transactions": [],
        }

    # 1. Total Students
    student_count = 0
    try:
        student_count = db.query(Student).filter(
            Student.academy_id == academy_id,
            Student.is_active == True
        ).count()
    except Exception as e:
        logger.error(f"[Dashboard] student_count error: {e}")

    # 2. Total Batches & Batches Data
    all_batches = []
    todays_classes_data = []
    try:
        all_batches = db.query(Batch).filter(Batch.academy_id == academy_id).all()
        today_name = datetime.now().strftime("%A").lower()

        for b in all_batches:
            is_today = bool(b.schedule_days and today_name in b.schedule_days.lower())
            timing_str = f"{b.start_time} - {b.end_time}" if (b.start_time and b.end_time) else (b.start_time or "Timing not set")
            if b.schedule_days:
                timing_str = f"{timing_str} • {b.schedule_days}"

            todays_classes_data.append({
                "id": str(b.id),
                "name": b.name,
                "timing": timing_str,
                "category": b.level or "Chess",
                "is_today": is_today,
            })
    except Exception as e:
        logger.error(f"[Dashboard] batches error: {e}")

    # 3. Income & Payments
    total_income = 0
    outstanding_dues = 0
    all_payments = []
    try:
        all_payments = db.query(Payment).join(Student).filter(
            Student.academy_id == academy_id
        ).all()

        for p in all_payments:
            p_status = getattr(p.status, 'value', str(p.status or '')).lower()
            amt_paid = p.amount_paid or 0
            amt_total = p.amount or 0
            if p_status in ['paid', 'partial']:
                total_income += amt_paid
            if p_status in ['unpaid', 'partial']:
                outstanding_dues += max(0, amt_total - amt_paid)
    except Exception as e:
        logger.error(f"[Dashboard] payments error: {e}")

    # 4. Recent Transactions
    tx_list = []
    try:
        expenses = db.query(Expense).filter(Expense.academy_id == academy_id).all()
        for p in all_payments[:5]:
            p_plan = getattr(p.plan_type, 'value', str(p.plan_type or 'Fee'))
            p_dt = getattr(p, 'created_at', None) or getattr(p, 'paid_at', None) or getattr(p, 'due_date', None)
            tx_list.append({
                "title": f"Subscription ({p_plan.capitalize()})",
                "month": _safe_date_fmt(p_dt, "%b %Y", "Aug 2026"),
                "amount": f"₹{p.amount_paid or 0}",
                "date": _safe_date_fmt(p_dt, "%d %b %Y", "08 Aug 2026"),
                "is_income": True,
            })

        for e in expenses[:5]:
            tx_list.append({
                "title": e.description if e.description else "Expense Logged",
                "month": _safe_date_fmt(e.expense_date, "%b %Y", "Aug 2026"),
                "amount": f"₹{e.amount or 0}",
                "date": _safe_date_fmt(e.expense_date, "%d %b %Y", "08 Aug 2026"),
                "is_income": False,
            })
    except Exception as e:
        logger.error(f"[Dashboard] transactions error: {e}")

    # 5. Academy Metadata
    academy_name = "Academy"
    academy_address = ""
    academy_phone = ""
    academy_email = ""
    academy_logo_url = None
    cat_val = "any"
    try:
        academy = db.query(Academy).filter(Academy.id == academy_id).first()
        if academy:
            academy_name = academy.name or "Academy"
            academy_address = academy.address or ""
            academy_phone = academy.phone or ""
            academy_email = academy.email or ""
            academy_logo_url = academy.logo_url
            cat_val = getattr(academy.category, 'value', str(academy.category or 'any'))
    except Exception as e:
        logger.error(f"[Dashboard] academy metadata error: {e}")

    return {
        "current_date": datetime.now().isoformat(),
        "total_students": student_count,
        "total_batches": len(all_batches),
        "upcoming_batches_today": len([c for c in todays_classes_data if c.get("is_today")]),
        "total_income": total_income,
        "outstanding_dues": outstanding_dues,
        "academy_name": academy_name,
        "academy_address": academy_address,
        "academy_phone": academy_phone,
        "academy_email": academy_email,
        "academy_logo_url": academy_logo_url,
        "academy_category": cat_val,
        "todays_classes": todays_classes_data,
        "recent_transactions": tx_list,
    }
