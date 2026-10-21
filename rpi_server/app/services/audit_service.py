"""Best-effort audit and application event trail in MongoDB.

Audit failures must never roll back a committed financial transaction, but they
are logged loudly so monitoring can detect a degraded analytics store. MySQL
remains the source of truth for every financial fact.
"""

from __future__ import annotations

import logging
from typing import Any

from pymongo.errors import PyMongoError

from app.core.context import get_request_id
from app.core.time import utc_now
from app.database.mongodb.client import get_mongo_database

logger = logging.getLogger(__name__)

AUDIT_COLLECTION = "audit_logs"
APPLICATION_EVENT_COLLECTION = "application_events"


def record_event(
    event_type: str,
    *,
    user_id: int | None = None,
    request_id: str | None = None,
    payload: dict[str, Any] | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> None:
    """Append an audit document. Failures are logged, never raised."""

    document: dict[str, Any] = {
        "event_type": event_type,
        "user_id": user_id,
        "request_id": request_id or get_request_id(),
        "created_at": utc_now(),
        "ip_address": ip_address,
        "user_agent": user_agent,
    }
    if payload:
        document["payload"] = payload
    try:
        get_mongo_database().database[AUDIT_COLLECTION].insert_one(document)
    except PyMongoError as exc:
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
    """Append a lightweight application event (auth, admin, lifecycle).

    This is separate from the audit log so operational events can be queried
    without scanning security records.
    """

    document: dict[str, Any] = {
        "event_type": event_type,
        "user_id": user_id,
        "request_id": request_id or get_request_id(),
        "created_at": utc_now(),
        "ip_address": ip_address,
        "user_agent": user_agent,
    }
    if payload:
        document["payload"] = payload
    try:
        get_mongo_database().database[
            APPLICATION_EVENT_COLLECTION
        ].insert_one(document)
    except PyMongoError as exc:
        logger.error(
            "Application event %s was not persisted: %s", event_type, exc
        )
