from typing import List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.deps import require_role
from app.models import AuditLog, User, UserRole

router = APIRouter(prefix="/audit-logs", tags=["audit"])


class AuditLogOut(BaseModel):
    id: str
    entity_type: str
    entity_id: str
    field_name: str
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    changed_by: str
    changed_by_name: Optional[str] = None
    changed_at: str


@router.get("", response_model=List[AuditLogOut])
async def list_audit_logs(
    entity_id: Optional[str] = None,
    limit: int = 100,
    current_user: User = Depends(require_role(UserRole.super_admin)),
):
    """Every field-level change written by update_academy() (and
    anything else that logs to AuditLog later) shows up here, newest
    first. Pass entity_id to see just one academy's history."""
    if entity_id:
        logs = await AuditLog.find(AuditLog.entity_id == entity_id).to_list()
    else:
        logs = await AuditLog.find().to_list()
    logs.sort(key=lambda log: log.changed_at, reverse=True)
    logs = logs[:limit]

    changer_ids = {log.changed_by for log in logs}
    changers = {}
    if changer_ids:
        users = await User.find(User.id.in_(list(changer_ids))).to_list()
        changers = {u.id: u.name for u in users}

    return [
        AuditLogOut(
            id=log.id,
            entity_type=log.entity_type,
            entity_id=log.entity_id,
            field_name=log.field_name,
            old_value=log.old_value,
            new_value=log.new_value,
            changed_by=log.changed_by,
            changed_by_name=changers.get(log.changed_by),
            changed_at=log.changed_at.isoformat(),
        )
        for log in logs
    ]
