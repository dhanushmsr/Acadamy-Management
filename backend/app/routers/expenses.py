from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.deps import require_academy_scope, require_role
from app.db import get_db
from app.models import Expense, User, UserRole
from app.schemas import ExpenseCreate, ExpenseOut

router = APIRouter(prefix="/expenses", tags=["expenses"])


@router.get("", response_model=list[ExpenseOut])
def list_expenses(
    db: Session = Depends(get_db),
    scope=Depends(require_academy_scope(UserRole.academy_admin, UserRole.coach)),
):
    _current_user, academy_id = scope
    return (
        db.query(Expense)
        .filter(Expense.academy_id == academy_id)
        .order_by(Expense.expense_date.desc())
        .all()
    )


@router.post("", response_model=ExpenseOut, status_code=status.HTTP_201_CREATED)
def create_expense(
    payload: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.academy_admin, UserRole.coach)),
):
    expense = Expense(
        academy_id=current_user.academy_id,
        created_by=current_user.id,
        amount=payload.amount,
        description=payload.description,
        expense_type=payload.expense_type,
        expense_date=payload.expense_date if payload.expense_date else None,
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense
