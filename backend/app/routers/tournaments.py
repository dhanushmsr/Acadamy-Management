from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.db import get_db
from app.models import User, UserRole, Tournament, TournamentRegistration, Student
from app.schemas import TournamentCreate, TournamentOut, TournamentRegistrationCreate, TournamentRegistrationOut
from app.core.deps import get_current_user

router = APIRouter(prefix="/tournaments", tags=["Tournaments"])

@router.get("", response_model=List[TournamentOut])
def get_tournaments(
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        if current_user.role == UserRole.super_admin:
            query = select(Tournament)
        else:
            if not current_user.academy_id:
                return []
            query = select(Tournament).where(Tournament.academy_id == current_user.academy_id)
        if status:
            query = query.where(Tournament.status == status)
        query = query.order_by(Tournament.created_at.desc() if hasattr(Tournament, 'created_at') else Tournament.id.desc())
        
        tournaments = db.scalars(query).all()
        results = []
        for t in tournaments:
            p_count = db.query(TournamentRegistration).filter(TournamentRegistration.tournament_id == t.id).count()
            t_out = TournamentOut.model_validate(t)
            t_out.participant_count = p_count
            fee = t.fee_amount or 0
            t_out.total_collected = p_count * fee
            results.append(t_out)
        return results
    except Exception as e:
        return []

@router.post("", response_model=TournamentOut, status_code=201)
def create_tournament(
    payload: TournamentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
    
    tournament = Tournament(
        academy_id=current_user.academy_id,
        **payload.model_dump()
    )
    db.add(tournament)
    db.commit()
    db.refresh(tournament)
    return tournament

@router.post("/{tournament_id}/register", response_model=TournamentRegistrationOut, status_code=201)
def register_student(
    tournament_id: str,
    payload: TournamentRegistrationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
        
    tournament = db.get(Tournament, tournament_id)
    if not tournament or str(tournament.academy_id) != str(current_user.academy_id):
        raise HTTPException(status_code=404, detail="Tournament not found")
        
    student = db.get(Student, payload.student_id)
    if not student or str(student.academy_id) != str(current_user.academy_id):
        raise HTTPException(status_code=404, detail="Student not found")
        
    existing = db.scalars(
        select(TournamentRegistration).where(
            TournamentRegistration.tournament_id == tournament_id,
            TournamentRegistration.student_id == payload.student_id
        )
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Student already registered for this tournament")
        
    registration = TournamentRegistration(
        tournament_id=tournament_id,
        student_id=payload.student_id
    )
    db.add(registration)
    db.commit()
    db.refresh(registration)
    return registration
