"""Persistence for ``AUDIT_LOG`` and ``APPLICATION_EVENT``.

Callers own the session and the commit.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.application_event import ApplicationEvent
from app.models.audit_log import AuditLog

_USER_AGENT_MAX = 512
_IP_MAX = 45
_REQUEST_ID_MAX = 128
_EVENT_TYPE_MAX = 64


def _clip(value: str | None, limit: int) -> str | None:
    return value[:limit] if value is not None else None


def _values(
    event_type: str,
    user_id: int | None,
    request_id: str | None,
    payload: dict[str, Any] | None,
    ip_address: str | None,
    user_agent: str | None,
    created_at: datetime,
) -> dict[str, Any]:
    return {
        "event_type": event_type[:_EVENT_TYPE_MAX],
        "user_id": user_id,
        "request_id": _clip(request_id, _REQUEST_ID_MAX),
        "ip_address": _clip(ip_address, _IP_MAX),
        "user_agent": _clip(user_agent, _USER_AGENT_MAX),
        "payload": payload or None,
        "created_at": created_at,
    }


def add_audit_log(
    db: Session,
    *,
    event_type: str,
    user_id: int | None,
    request_id: str | None,
    payload: dict[str, Any] | None,
    ip_address: str | None,
    user_agent: str | None,
    created_at: datetime,
) -> AuditLog:
    row = AuditLog(
        **_values(
            event_type,
            user_id,
            request_id,
            payload,
            ip_address,
            user_agent,
            created_at,
        )
    )
    db.add(row)
    db.flush()
    return row


def add_application_event(
    db: Session,
    *,
    event_type: str,
    user_id: int | None,
    request_id: str | None,
    payload: dict[str, Any] | None,
    ip_address: str | None,
    user_agent: str | None,
    created_at: datetime,
) -> ApplicationEvent:
    row = ApplicationEvent(
        **_values(
            event_type,
            user_id,
            request_id,
            payload,
            ip_address,
            user_agent,
            created_at,
        )
    )
    db.add(row)
    db.flush()
    return row


def count_audit_logs(db: Session) -> int:
    return int(db.scalar(select(func.count(AuditLog.id))) or 0)


def count_application_events(db: Session) -> int:
    return int(db.scalar(select(func.count(ApplicationEvent.id))) or 0)
