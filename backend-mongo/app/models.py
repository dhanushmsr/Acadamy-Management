"""
Beanie (MongoDB) version of every entity from the Postgres schema.

Design notes:

- IDs are UUID strings, not Mongo's default ObjectId, so API response
  shapes - and therefore the Flutter app - don't change at all. Every
  *Out schema in schemas.py is untouched by this port.

- References between collections are stored as plain ID strings (like
  the old ForeignKey columns), not Beanie's Link[] type. Simpler to
  reason about, and matches the "fetch, then fetch again" pattern the
  routers already use (see students.py for a concrete example - the
  parent_name/parent_phone lookup that used to be a free SQLAlchemy
  relationship is now an explicit batch query).

- Four entities are embedded in their parent instead of getting their
  own collection, because they're always read/written alongside a
  bounded parent and never queried on their own - the textbook case for
  embedding in Mongo:
    * BroadcastRecipient -> Broadcast.recipients
    * Lesson             -> Course.lessons
    * GameReview         -> Game.reviews
    * TournamentRegistration -> Tournament.registrations
  Everything else stays a top-level collection, mainly because it
  either grows without bound over time (Attendance, PuzzleAttempt,
  RatingHistory, Notification, Payment - one row per event, forever) or
  needs to be queried/indexed independently of whatever created it
  (Student, Payment, Game).
"""
import uuid
from datetime import datetime
from enum import Enum
from typing import List, Optional

from beanie import Document, Indexed
from pydantic import BaseModel, Field


def gen_uuid() -> str:
    return str(uuid.uuid4())


# ---- Enums -----------------------------------------------------------
# Unchanged in name and value from the Postgres version. schemas.py
# imports these directly, so keeping them identical means schemas.py
# needs zero edits for this port.

class UserRole(str, Enum):
    super_admin = "super_admin"
    academy_admin = "academy_admin"
    coach = "coach"
    student = "student"
    parent = "parent"


class AcademyStatus(str, Enum):
    active = "active"
    suspended = "suspended"
    deleted = "deleted"


class MessageType(str, Enum):
    custom = "custom"
    payment_reminder = "payment_reminder"


class RecipientStatus(str, Enum):
    pending = "pending"
    sent = "sent"
    failed = "failed"


class AttendanceStatus(str, Enum):
    present = "present"
    absent = "absent"


class GameResult(str, Enum):
    win = "win"
    loss = "loss"
    draw = "draw"


class TournamentType(str, Enum):
    in_house = "in_house"
    third_party = "third_party"


class PlanType(str, Enum):
    monthly = "monthly"
    quarterly = "quarterly"
    yearly = "yearly"


class PaymentStatus(str, Enum):
    unpaid = "unpaid"
    partial = "partial"
    paid = "paid"


class NotificationType(str, Enum):
    class_reminder = "class_reminder"
    class_cancelled = "class_cancelled"
    tournament = "tournament"
    fee_due = "fee_due"
    new_assignment = "new_assignment"
    new_lesson = "new_lesson"
    tournament_result = "tournament_result"
    achievement = "achievement"


# ---- Platform layer ---------------------------------------------------

class Academy(Document):
    id: str = Field(default_factory=gen_uuid)
    name: str
    logo_url: Optional[str] = None
    address: Optional[str] = None
    status: AcademyStatus = AcademyStatus.active
    phone: Optional[str] = None
    email: Optional[str] = None
    tagline: Optional[str] = None
    created_by: Optional[str] = None  # id of the super admin who created it
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "academies"


class User(Document):
    id: str = Field(default_factory=gen_uuid)
    name: str
    email: Indexed(str, unique=True)
    phone: Optional[str] = None
    hashed_password: str
    role: UserRole
    academy_id: Optional[str] = None
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "users"


class AuditLog(Document):
    id: str = Field(default_factory=gen_uuid)
    entity_type: str  # e.g. "academy"
    entity_id: str
    field_name: str
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    changed_by: str
    changed_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "audit_logs"


# ---- Roster -------------------------------------------------------------

class Parent(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    user_id: Optional[str] = None  # set once the parent has their own login
    name: str
    phone: str  # E.164, e.g. +919876543210
    alternate_phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None

    class Settings:
        name = "parents"


class Student(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    parent_id: Optional[str] = None
    user_id: Optional[str] = None  # set once the student has their own login
    batch_id: Optional[str] = None
    student_number: Optional[int] = None  # academy-scoped, e.g. shown as PER-000143
    name: str
    photo_url: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    level: Optional[str] = None
    current_rating: int = 0
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "students"


# ---- Messaging (WhatsApp) ------------------------------------------------

class BroadcastRecipient(BaseModel):
    """Embedded, not its own collection - always read/written as part of
    its Broadcast, never queried on its own."""

    student_id: str
    phone: str
    status: RecipientStatus = RecipientStatus.pending
    provider_message_id: Optional[str] = None
    error_message: Optional[str] = None
    sent_at: Optional[datetime] = None


class Broadcast(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    created_by: str
    message_type: MessageType = MessageType.custom
    body: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    recipients: List[BroadcastRecipient] = []

    class Settings:
        name = "broadcasts"


# ---- Batches, classes, attendance ----------------------------------------

class Batch(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    coach_id: Optional[str] = None
    name: str  # e.g. "King Chess Junior Batch"
    level: Optional[str] = None
    schedule_days: Optional[str] = None  # e.g. "Mon,Wed,Fri"
    start_time: Optional[str] = None  # "18:30"
    end_time: Optional[str] = None
    is_active: bool = True

    class Settings:
        name = "batches"


class ClassSession(Document):
    """One scheduled occurrence of a batch - own collection because it
    grows without bound over a batch's lifetime (embedding it in Batch
    would mean an ever-growing array inside one document, a well-known
    Mongo anti-pattern)."""

    id: str = Field(default_factory=gen_uuid)
    batch_id: str
    topic: Optional[str] = None  # e.g. "Endgame Training"
    scheduled_at: datetime
    is_cancelled: bool = False
    cancellation_reason: Optional[str] = None

    class Settings:
        name = "class_sessions"


class Attendance(Document):
    """Own collection for the same unbounded-growth reason as
    ClassSession - one row per student per session, forever."""

    id: str = Field(default_factory=gen_uuid)
    class_session_id: str
    student_id: str
    status: AttendanceStatus
    marked_by: Optional[str] = None
    marked_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "attendance"


# ---- Courses & lessons -----------------------------------------------------

class Lesson(BaseModel):
    """Embedded in Course - a course's lesson list is small, bounded,
    and always shown together with the course."""

    id: str = Field(default_factory=gen_uuid)
    title: str
    content_url: Optional[str] = None
    order_index: int = 0


class Course(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    title: str
    description: Optional[str] = None
    created_by: Optional[str] = None
    lessons: List[Lesson] = []

    class Settings:
        name = "courses"


# ---- Assignments --------------------------------------------------------

class Assignment(Document):
    """Own collection, not embedded in Batch/Course - assignments are
    queried on their own axis (e.g. 'everything due today' for the
    student dashboard), and AssignmentSubmission needs a stable id to
    point back to."""

    id: str = Field(default_factory=gen_uuid)
    batch_id: Optional[str] = None
    lesson_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    created_by: Optional[str] = None

    class Settings:
        name = "assignments"


class AssignmentSubmission(Document):
    """Own collection - a student's full submission history needs to be
    queryable in one shot (`student_id == X`), which is awkward if
    submissions are scattered across many different Assignment
    documents' embedded arrays instead."""

    id: str = Field(default_factory=gen_uuid)
    assignment_id: str
    student_id: str
    is_complete: bool = False
    submitted_at: Optional[datetime] = None

    class Settings:
        name = "assignment_submissions"


# ---- Puzzles --------------------------------------------------------------

class Puzzle(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: Optional[str] = None  # null = shared/global puzzle
    fen: str  # starting chess position
    solution: str  # moves in algebraic notation
    difficulty: Optional[str] = None  # "easy" / "medium" / "hard"

    class Settings:
        name = "puzzles"


class PuzzleAttempt(Document):
    id: str = Field(default_factory=gen_uuid)
    puzzle_id: str
    student_id: str
    solved: bool
    attempted_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "puzzle_attempts"


# ---- Games ------------------------------------------------------------

class GameReview(BaseModel):
    """Embedded in Game - a coach leaves at most a couple of reviews per
    game, always viewed alongside the game itself."""

    coach_id: str
    comments: Optional[str] = None
    reviewed_at: datetime = Field(default_factory=datetime.utcnow)


class Game(Document):
    id: str = Field(default_factory=gen_uuid)
    student_id: str
    opponent_name: Optional[str] = None
    pgn: Optional[str] = None  # full move notation, for board replay
    result: Optional[GameResult] = None
    played_at: datetime = Field(default_factory=datetime.utcnow)
    reviews: List[GameReview] = []

    class Settings:
        name = "games"


# ---- Ratings ------------------------------------------------------------

class RatingHistory(Document):
    """Own collection - unbounded growth over a student's career, and
    needs to support 'rating over time' queries for the parent
    dashboard's progression chart."""

    id: str = Field(default_factory=gen_uuid)
    student_id: str
    rating: int
    recorded_at: datetime = Field(default_factory=datetime.utcnow)
    note: Optional[str] = None  # e.g. "After Puliyankudi Open, Round 5"

    class Settings:
        name = "rating_history"


# ---- Tournaments --------------------------------------------------------

class TournamentRegistration(BaseModel):
    """Embedded in Tournament - bounded by how many students sign up for
    one event, always viewed as a roster together."""

    student_id: str
    registered_at: datetime = Field(default_factory=datetime.utcnow)


class Tournament(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    name: str
    organizer_name: Optional[str] = None
    tournament_type: TournamentType = TournamentType.in_house
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    reporting_time: Optional[datetime] = None
    venue: Optional[str] = None
    fee_amount: Optional[int] = None
    notes: Optional[str] = None
    banner_url: Optional[str] = None
    brochure_url: Optional[str] = None
    registrations: List[TournamentRegistration] = []

    class Settings:
        name = "tournaments"


# ---- Payments -----------------------------------------------------------

class Payment(Document):
    """No payment gateway - the academy manager sets status by hand
    (cash, bank transfer, whatever happened outside the app). This is a
    monitoring/tracking record, not a transaction. Own collection since
    it needs independent indexing/querying (a student's payment
    history, or every unpaid fee across the academy)."""

    id: str = Field(default_factory=gen_uuid)
    student_id: str
    plan_type: PlanType
    amount: int  # total due
    amount_paid: int = 0  # running total, for "partial"
    status: PaymentStatus = PaymentStatus.unpaid
    due_date: Optional[datetime] = None
    paid_at: Optional[datetime] = None  # set the moment status first reaches "paid"
    invoice_number: Optional[str] = None

    class Settings:
        name = "payments"


# ---- Notifications --------------------------------------------------------

class Notification(Document):
    id: str = Field(default_factory=gen_uuid)
    recipient_user_id: str
    type: NotificationType
    title: str
    body: Optional[str] = None
    is_read: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "notifications"


# ---- Calendar / holidays ----

class Holiday(Document):
    id: str = Field(default_factory=gen_uuid)
    academy_id: str
    date: datetime  # stored at midnight, one document per day
    reason: Optional[str] = None

    class Settings:
        name = "holidays"
