"""Best-effort audit and application event trail in MySQL.

Audit failures must never roll back a committed financial transaction. Each
event is written in its own short session and transaction, so it is
independent of the request's session, and any failure is logged loudly (so
monitoring can detect a degraded audit store) but never raised.

Callers must not hold row locks when recording an event: the audit row has a
foreign key to ``users`` and a separate connection would wait for them.
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.context import get_request_id
from app.core.time import utc_now_naive
from app.database.mysql.session import SessionLocal
from app.repositories import audit_repository

logger = logging.getLogger(__name__)


def record_event(
    event_type: str,
    *,
    user_id: int | None = None,
    request_id: str | None = None,
    payload: dict[str, Any] | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> None:
    """Append an ``AUDIT_LOG`` row. Failures are logged, never raised."""

    try:
        with SessionLocal() as db:
            audit_repository.add_audit_log(
                db,
                event_type=event_type,
                user_id=user_id,
                request_id=request_id or get_request_id(),
                payload=payload,
                ip_address=ip_address,
                user_agent=user_agent,
                created_at=utc_now_naive(),
            )
            db.commit()
    except Exception as exc:  # best effort by contract
        logger.error("Audit event %s was not persisted: %s", event_type, exc)


def record_application_event(
    event_type: str,
    *,
    user_id: int | None = None,
    request_id: str | None = None,
    payload: dict[str, Any] | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> None:
    """Append a lightweight ``APPLICATION_EVENT`` (auth, admin, lifecycle).

    Separate from the audit log so operational events can be queried without
    scanning security records. Failures are logged, never raised.
    """

    try:
        with SessionLocal() as db:
            audit_repository.add_application_event(
                db,
                event_type=event_type,
                user_id=user_id,
                request_id=request_id or get_request_id(),
                payload=payload,
                ip_address=ip_address,
                user_agent=user_agent,
                created_at=utc_now_naive(),
            )
            db.commit()
    except Exception as exc:  # best effort by contract
        logger.error(
            "Application event %s was not persisted: %s", event_type, exc
        )
