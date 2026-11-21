"""``APPLICATION_EVENT``: lightweight auth, admin and lifecycle events.

Replaces the former ``application_events`` document collection. Kept apart
from ``AUDIT_LOG`` so operational events can be queried without scanning
security records. Append-only and best-effort (see ``audit_service``).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Index,
    String,
)
from sqlalchemy.dialects.mysql import DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now_naive
from app.database.mysql.base import Base


class ApplicationEvent(Base):
    __tablename__ = "APPLICATION_EVENT"
    __table_args__ = (
        CheckConstraint(
            "CHAR_LENGTH(TRIM(event_type)) > 0",
            name="ck_application_event_event_type",
        ),
        Index("ix_application_event_user_created", "user_id", "created_at"),
        Index("ix_application_event_request", "request_id"),
        Index("ix_application_event_event_created", "event_type", "created_at"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_0900_ai_ci",
        },
    )

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    # NULL for events with no authenticated user; kept if the user is removed.
    user_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL", name="fk_application_event_user"),
        nullable=True,
    )
    request_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(512), nullable=True)
    payload: Mapped[dict[str, Any] | None] = mapped_column(
        JSON, nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=6), nullable=False, default=utc_now_naive
    )
