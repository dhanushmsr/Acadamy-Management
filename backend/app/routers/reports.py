from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from app.db import get_db
from app.models import User, Student, Payment, PaymentStatus, Expense, Attendance, AttendanceStatus, ClassSession
from app.schemas import ReportSummary
from app.core.deps import get_current_user

router = APIRouter(prefix="/reports", tags=["Reports"])

@router.get("/summary", response_model=ReportSummary)
def get_report_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
    
    academy_id = current_user.academy_id

    # 1. Total Students
    total_students = db.scalar(
        select(func.count(Student.id)).where(Student.academy_id == academy_id, Student.is_active == True)
    ) or 0

    # 2. Total Revenue (Payments)
    total_revenue = db.scalar(
        select(func.sum(Payment.amount_paid)).join(Student).where(
            Student.academy_id == academy_id,
            Payment.status.in_([PaymentStatus.paid, PaymentStatus.partial])
        )
    ) or 0

    # 3. Total Expenses
    total_expenses = db.scalar(
        select(func.sum(Expense.amount)).where(Expense.academy_id == academy_id)
    ) or 0

    # 4. Net Profit
    net_profit = total_revenue - total_expenses

    # 5. Average Attendance Percentage
    # Get all attendance records for students in this academy
    attendance_records = db.execute(
        select(Attendance.status)
        .join(Student)
        .where(Student.academy_id == academy_id)
    ).scalars().all()

    total_records = len(attendance_records)
    if total_records == 0:
        average_attendance_percentage = 0.0
    else:
        present_count = sum(1 for status in attendance_records if status == AttendanceStatus.present)
        average_attendance_percentage = (present_count / total_records) * 100

    return ReportSummary(
        total_students=total_students,
        total_revenue=total_revenue,
        total_expenses=total_expenses,
        net_profit=net_profit,
        average_attendance_percentage=round(average_attendance_percentage, 2)
    )
