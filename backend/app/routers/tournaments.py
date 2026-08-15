from datetime import datetime
import uuid
import logging
from typing import List, Optional
import httpx
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from app.db import get_db
from app.models import (
    User,
    UserRole,
    Tournament,
    TournamentRegistration,
    Student,
    Academy,
    Notification,
    NotificationType,
)
from app.schemas import (
    TournamentCreate,
    TournamentOut,
    PublicTournamentOut,
    TournamentRegistrationCreate,
    TournamentRegistrationOut,
    RazorpayOrderRequest,
    RazorpayOrderResponse,
    RazorpayVerifyRequest,
)
from app.core.deps import get_current_user
from app.core.config import settings
from app.integrations.email import send_email, render_tournament_invoice_html

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tournaments", tags=["Tournaments"])


# ---- PUBLIC ENDPOINTS (No Authentication Required) ----

@router.get("/public/{tournament_id}", response_model=PublicTournamentOut)
def get_public_tournament(tournament_id: str, db: Session = Depends(get_db)):
    tournament = db.get(Tournament, tournament_id)
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    academy = db.get(Academy, tournament.academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Associated academy not found")

    now = datetime.utcnow()
    is_expired = False
    if tournament.end_date and tournament.end_date < now:
        is_expired = True
    elif tournament.status in ["completed", "expired"]:
        is_expired = True

    p_count = db.query(TournamentRegistration).filter(
        TournamentRegistration.tournament_id == tournament.id
    ).count()

    return PublicTournamentOut(
        id=str(tournament.id),
        academy_id=str(academy.id),
        academy_name=academy.name,
        academy_logo=academy.logo_url,
        academy_phone=academy.phone,
        academy_email=academy.email,
        academy_tagline=academy.tagline,
        name=tournament.name,
        organizer_name=tournament.organizer_name,
        organizer_phone=tournament.organizer_phone,
        organizer_email=tournament.organizer_email,
        sports=tournament.sports or "Chess",
        category=tournament.category or "Open",
        status=tournament.status or "open",
        start_date=tournament.start_date,
        end_date=tournament.end_date,
        reporting_time=tournament.reporting_time,
        venue=tournament.venue,
        city_or_place=tournament.city_or_place,
        fee_amount=tournament.fee_amount or 0,
        notes=tournament.notes,
        rules_and_prizes=tournament.rules_and_prizes,
        result_url=tournament.result_url,
        banner_url=tournament.banner_url,
        brochure_url=tournament.brochure_url,
        is_expired=is_expired,
        participant_count=p_count,
    )


@router.post("/public/{tournament_id}/create-order", response_model=RazorpayOrderResponse)
def create_razorpay_order(
    tournament_id: str,
    payload: RazorpayOrderRequest,
    db: Session = Depends(get_db),
):
    tournament = db.get(Tournament, tournament_id)
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    now = datetime.utcnow()
    if (tournament.end_date and tournament.end_date < now) or tournament.status in ["completed", "expired"]:
        raise HTTPException(status_code=400, detail="This tournament has ended and link has expired")

    fee = tournament.fee_amount or 0
    amount_in_paise = fee * 100

    # Create pending registration record
    reg_id = str(uuid.uuid4())
    order_id = f"order_rzp_{uuid.uuid4().hex[:12]}"
    
    # Try calling Razorpay API if configured
    rzp_key_id = getattr(settings, "razorpay_key_id", None) or "rzp_test_AcDMan2025Key"
    rzp_secret = getattr(settings, "razorpay_key_secret", None) or "secret_AcDMan2026"
    
    if getattr(settings, "razorpay_key_id", None) and getattr(settings, "razorpay_key_secret", None):
        try:
            url = "https://api.razorpay.com/v1/orders"
            resp = httpx.post(
                url,
                auth=(rzp_key_id, rzp_secret),
                json={"amount": amount_in_paise or 100, "currency": "INR", "receipt": reg_id[:16]},
                timeout=5.0,
            )
            if resp.status_code in [200, 201]:
                order_id = resp.json().get("id", order_id)
        except Exception as e:
            logger.warning(f"Razorpay API call exception: {e}")

    registration = TournamentRegistration(
        id=reg_id,
        tournament_id=tournament.id,
        student_id=payload.student_id,
        participant_name=payload.participant_name.strip(),
        participant_phone=payload.participant_phone.strip(),
        participant_email=payload.participant_email.strip(),
        participant_dob=payload.participant_dob,
        payment_status="pending",
        razorpay_order_id=order_id,
        amount_paid=fee,
    )
    db.add(registration)
    db.commit()

    return RazorpayOrderResponse(
        order_id=order_id,
        key_id=rzp_key_id,
        amount=amount_in_paise if amount_in_paise > 0 else 100,
        currency="INR",
        registration_id=reg_id,
        tournament_name=tournament.name,
    )


@router.post("/public/verify-payment", response_model=TournamentRegistrationOut)
def verify_tournament_payment(
    payload: RazorpayVerifyRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    reg = db.get(TournamentRegistration, payload.registration_id)
    if not reg:
        raise HTTPException(status_code=404, detail="Registration record not found")

    reg.payment_status = "paid"
    reg.razorpay_payment_id = payload.razorpay_payment_id or f"pay_rzp_{uuid.uuid4().hex[:12]}"
    reg.registered_at = datetime.utcnow()
    db.commit()
    db.refresh(reg)

    tournament = db.get(Tournament, reg.tournament_id)
    academy = db.get(Academy, tournament.academy_id) if tournament else None

    academy_name = academy.name if academy else "Academy"
    t_name = tournament.name if tournament else "Tournament"
    p_name = reg.participant_name or "Participant"
    p_email = reg.participant_email or ""
    amount_paid = reg.amount_paid or 0

    # 1. Send Notifications to Academy Admin and Super Admin
    try:
        # Notify Academy Admins
        if academy:
            acad_admins = db.query(User).filter(
                User.academy_id == academy.id,
                User.role == UserRole.academy_admin
            ).all()
            for admin in acad_admins:
                n = Notification(
                    recipient_user_id=admin.id,
                    type=NotificationType.tournament,
                    title=f"🏆 New Registration: {t_name}",
                    body=f"{p_name} registered and paid ₹{amount_paid}. Payment ID: {reg.razorpay_payment_id}"
                )
                db.add(n)

        # Notify Super Admins
        super_admins = db.query(User).filter(User.role == UserRole.super_admin).all()
        for sa in super_admins:
            n = Notification(
                recipient_user_id=sa.id,
                type=NotificationType.tournament,
                title=f"💳 Tournament Payment: {t_name} ({academy_name})",
                body=f"{p_name} paid ₹{amount_paid} for {t_name} at {academy_name}. Payment ID: {reg.razorpay_payment_id}"
            )
            db.add(n)

        db.commit()
    except Exception as e:
        logger.warning(f"Error creating tournament notifications: {e}")

    # 2. Email Receipt/Invoice to Participant
    if p_email:
        date_str = tournament.start_date.strftime("%d %b %Y") if (tournament and tournament.start_date) else "TBA"
        rep_time = tournament.reporting_time.strftime("%I:%M %p") if (tournament and tournament.reporting_time) else ""
        venue_str = f"{tournament.venue or 'Main Center'}, {tournament.city_or_place or ''}".strip(", ") if tournament else "Academy Center"

        invoice_html = render_tournament_invoice_html(
            academy_name=academy_name,
            tournament_name=t_name,
            participant_name=p_name,
            amount=amount_paid,
            payment_id=reg.razorpay_payment_id,
            order_id=reg.razorpay_order_id or "N/A",
            date_str=date_str,
            venue=venue_str,
            reporting_time=rep_time,
            academy_phone=academy.phone if academy else "",
            academy_email=academy.email if academy else "",
        )
        subject = f"Registration Invoice & Receipt - {t_name} ({academy_name})"
        background_tasks.add_task(send_email, p_email, subject, invoice_html)

    return reg


# ---- AUTHENTICATED ENDPOINTS (Academy Admin & Super Admin) ----

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
        query = query.order_by(Tournament.created_at.desc())
        
        tournaments = db.scalars(query).all()
        now = datetime.utcnow()
        results = []

        for t in tournaments:
            # Auto-check completion / link expiry
            if t.end_date and t.end_date < now and t.status == "open":
                t.status = "completed"
                db.commit()

            paid_regs = db.query(TournamentRegistration).filter(
                TournamentRegistration.tournament_id == t.id,
                TournamentRegistration.payment_status == "paid"
            ).all()

            p_count = len(paid_regs)
            total_sum = sum(r.amount_paid for r in paid_regs if r.amount_paid) or (p_count * (t.fee_amount or 0))

            t_out = TournamentOut.model_validate(t)
            t_out.participant_count = p_count
            t_out.total_collected = total_sum
            results.append(t_out)
        return results
    except Exception as e:
        logger.error(f"Error fetching tournaments: {e}")
        return []


@router.post("", response_model=TournamentOut, status_code=201)
def create_tournament(
    payload: TournamentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not current_user.academy_id:
        raise HTTPException(status_code=403, detail="Not associated with an academy")
    
    data = payload.model_dump()
    tournament = Tournament(
        academy_id=current_user.academy_id,
        **data
    )
    db.add(tournament)
    db.commit()
    db.refresh(tournament)

    # Attach stats
    t_out = TournamentOut.model_validate(tournament)
    t_out.participant_count = 0
    t_out.total_collected = 0
    return t_out


@router.get("/{tournament_id}/registrations", response_model=List[TournamentRegistrationOut])
def get_tournament_registrations(
    tournament_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tournament = db.get(Tournament, tournament_id)
    if not tournament:
        raise HTTPException(status_code=404, detail="Tournament not found")

    if current_user.role != UserRole.super_admin and str(tournament.academy_id) != str(current_user.academy_id):
        raise HTTPException(status_code=403, detail="Access denied")

    regs = db.scalars(
        select(TournamentRegistration)
        .where(
            TournamentRegistration.tournament_id == tournament_id,
            TournamentRegistration.payment_status == "paid"
        )
        .order_by(TournamentRegistration.registered_at.desc())
    ).all()

    return regs


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
        
    student = None
    if payload.student_id:
        student = db.get(Student, payload.student_id)
        if not student or str(student.academy_id) != str(current_user.academy_id):
            raise HTTPException(status_code=404, detail="Student not found")
        
    registration = TournamentRegistration(
        tournament_id=tournament_id,
        student_id=payload.student_id,
        participant_name=payload.participant_name or (student.name if student else "Participant"),
        participant_phone=payload.participant_phone or (student.parent_phone if student else ""),
        participant_email=payload.participant_email or (student.parent_email if student else ""),
        participant_dob=payload.participant_dob or (student.date_of_birth if student else None),
        payment_status="paid",
        amount_paid=tournament.fee_amount or 0,
        registered_at=datetime.utcnow(),
    )
    db.add(registration)
    db.commit()
    db.refresh(registration)
    return registration
