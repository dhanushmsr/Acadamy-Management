from datetime import datetime, date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.deps import require_role
from app.db import get_db
from app.models import Batch, Payment, PaymentStatus, Student, User, UserRole, Expense, Academy

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

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

    try:
        # 1. Total Students
        student_count = db.query(Student).filter(
            Student.academy_id == academy_id,
            Student.is_active == True
        ).count()

        # 2. Total Batches
        all_batches = db.query(Batch).filter(
            Batch.academy_id == academy_id
        ).all()
        batch_count = len(all_batches)

        # 3. All Academy Batches
        today_name = datetime.now().strftime("%A").lower()

        todays_classes_data = []
        for b in all_batches:
            is_today = bool(b.schedule_days and today_name in b.schedule_days.lower())
            timing_str = f"{b.start_time} - {b.end_time}" if (b.start_time and b.end_time) else (b.start_time or "Timing not set")
            if b.schedule_days:
                timing_str = f"{timing_str} • {b.schedule_days}"

            todays_classes_data.append({
                "id": b.id,
                "name": b.name,
                "timing": timing_str,
                "category": b.level or "Chess",
                "is_today": is_today,
            })

        # 4. Total Income & Outstanding Dues
        all_payments = db.query(Payment).join(Student).filter(
            Student.academy_id == academy_id
        ).all()
        
        total_income = sum([p.amount_paid for p in all_payments if p.status in [PaymentStatus.paid, PaymentStatus.partial]])
        outstanding_dues = sum([(p.amount - p.amount_paid) for p in all_payments if p.status in [PaymentStatus.unpaid, PaymentStatus.partial]])

        # 5. Recent Transactions
        expenses = db.query(Expense).filter(Expense.academy_id == academy_id).all()

        tx_list = []
        for p in all_payments[:5]:
            p_plan = getattr(p.plan_type, 'value', str(p.plan_type)) if p.plan_type else 'Fee'
            tx_list.append({
                "title": f"Subscription ({p_plan.capitalize()})",
                "month": p.created_at.strftime("%b %Y") if p.created_at else "Aug 2026",
                "amount": f"₹{p.amount_paid}",
                "date": p.created_at.strftime("%d %b %Y") if p.created_at else "08 Aug 2026",
                "is_income": True,
            })

        for e in expenses[:5]:
            tx_list.append({
                "title": e.description if e.description else "Expense Logged",
                "month": e.expense_date.strftime("%b %Y") if e.expense_date else "Aug 2026",
                "amount": f"₹{e.amount}",
                "date": e.expense_date.strftime("%d %b %Y") if e.expense_date else "08 Aug 2026",
                "is_income": False,
            })

        academy = db.query(Academy).filter(Academy.id == academy_id).first()
        cat_val = getattr(academy.category, 'value', str(academy.category or 'any')) if academy else "any"

        return {
            "current_date": datetime.now().isoformat(),
            "total_students": student_count,
            "total_batches": batch_count,
            "upcoming_batches_today": len(todays_batches),
            "total_income": total_income,
            "outstanding_dues": outstanding_dues,
            "academy_name": academy.name if academy else "Academy",
            "academy_address": academy.address if academy else "",
            "academy_phone": academy.phone if academy else "",
            "academy_email": academy.email if academy else "",
            "academy_logo_url": academy.logo_url if academy else None,
            "academy_category": cat_val,
            "todays_classes": todays_classes_data,
            "recent_transactions": tx_list,
        }
    except Exception as err:
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
