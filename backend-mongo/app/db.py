"""
Motor (async MongoDB driver) client + Beanie ODM initialization.

Beanie documents (see models.py) double as both the schema AND the
query interface - there's no separate Session object to create and pass
into every route like there was with SQLAlchemy. Each route just calls
`await SomeDocument.find(...)` / `.get(...)` / `.insert()` directly.
"""
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings

client = AsyncIOMotorClient(settings.mongodb_url)
database = client[settings.mongodb_db_name]


async def init_db() -> None:
    """Called once from main.py's lifespan startup - registers every
    Document model with Beanie so their query methods work. Imported
    here (not at module top-level) to avoid a circular import with
    models.py, which doesn't need anything from this file until this
    function actually runs."""
    from beanie import init_beanie

    from app.models import (
        Academy,
        Assignment,
        AssignmentSubmission,
        Attendance,
        AuditLog,
        Batch,
        Broadcast,
        ClassSession,
        Course,
        Game,
        Holiday,
        Notification,
        Parent,
        Payment,
        Puzzle,
        PuzzleAttempt,
        RatingHistory,
        Student,
        Tournament,
        User,
    )

    await init_beanie(
        database=database,
        document_models=[
            Academy,
            User,
            AuditLog,
            Parent,
            Student,
            Broadcast,
            Batch,
            ClassSession,
            Attendance,
            Course,
            Assignment,
            AssignmentSubmission,
            Puzzle,
            PuzzleAttempt,
            Game,
            RatingHistory,
            Tournament,
            Payment,
            Notification,
            Holiday,
        ],
    )
