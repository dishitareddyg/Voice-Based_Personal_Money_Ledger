"""Persistence for ``VOICE_COMMAND``. Callers own the session and commit."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.orm import Session

from app.models.voice_command import VoiceCommand


def record_once(
    db: Session,
    *,
    user_id: int,
    request_id: str,
    voice_text: str,
    parser_confidence: float | None,
    transaction_id: int | None,
    nlp: dict[str, Any],
    source: str,
    created_at: datetime,
) -> None:
    """Insert one row per (user_id, request_id); a retry changes nothing.

    ``ON DUPLICATE KEY UPDATE id = id`` is an atomic no-op, so concurrent
    retries cannot create duplicates and the first stored row always wins
    (the behaviour of the former ``$setOnInsert`` upsert). Unlike
    ``INSERT IGNORE`` it does not hide foreign-key or data errors.
    """

    table = VoiceCommand.__table__
    stmt = (
        mysql_insert(table)
        .values(
            user_id=user_id,
            request_id=request_id,
            voice_text=voice_text,
            parser_confidence=parser_confidence,
            transaction_id=transaction_id,
            nlp=nlp,
            source=source,
            created_at=created_at,
        )
        .on_duplicate_key_update(id=table.c.id)
    )
    db.execute(stmt)


def get_by_request(
    db: Session, user_id: int, request_id: str
) -> VoiceCommand | None:
    return db.scalar(
        select(VoiceCommand).where(
            VoiceCommand.user_id == user_id,
            VoiceCommand.request_id == request_id,
        )
    )


def count(db: Session) -> int:
    return int(db.scalar(select(func.count(VoiceCommand.id))) or 0)
