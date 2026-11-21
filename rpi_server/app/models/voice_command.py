"""``VOICE_COMMAND``: confirmed voice text and extraction metadata.

Replaces the former ``voice_commands`` document collection. Only confirmed
text is stored; audio never reaches the server. The financial effect of a
command lives exclusively in ``transactions``.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    BigInteger,
    CheckConstraint,
    Double,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.mysql import DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now_naive
from app.database.mysql.base import Base


class VoiceCommand(Base):
    __tablename__ = "VOICE_COMMAND"
    __table_args__ = (
        # Idempotency: one stored command per (user, client request).
        UniqueConstraint(
            "user_id", "request_id", name="uq_voice_command_user_request"
        ),
        CheckConstraint(
            "parser_confidence IS NULL "
            "OR (parser_confidence >= 0 AND parser_confidence <= 1)",
            name="ck_voice_command_confidence",
        ),
        CheckConstraint(
            "CHAR_LENGTH(request_id) >= 8",
            name="ck_voice_command_request_id_length",
        ),
        # Newest-first listing per user (a backward index scan serves DESC).
        Index("ix_voice_command_user_created", "user_id", "created_at"),
        Index("ix_voice_command_transaction", "transaction_id"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_0900_ai_ci",
        },
    )

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "users.id", ondelete="CASCADE", name="fk_voice_command_user"
        ),
        nullable=False,
    )
    request_id: Mapped[str] = mapped_column(String(64), nullable=False)
    voice_text: Mapped[str] = mapped_column(Text, nullable=False)
    parser_confidence: Mapped[float | None] = mapped_column(
        Double, nullable=True
    )
    transaction_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey(
            "transactions.id",
            ondelete="SET NULL",
            name="fk_voice_command_transaction",
        ),
        nullable=True,
    )
    # Variable extraction metadata (intent, category, person, ...).
    nlp: Mapped[dict[str, Any]] = mapped_column(
        JSON, nullable=False, default=dict
    )
    source: Mapped[str] = mapped_column(
        String(64), nullable=False, default="android_speech_recognizer"
    )
    created_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=6), nullable=False, default=utc_now_naive
    )
