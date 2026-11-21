"""Voice command metadata in MySQL (``VOICE_COMMAND``).

Only confirmed text is stored. Audio never reaches the server. The table keeps
the original transcript, parser confidence and extraction metadata for
analytics and evaluation; the financial effect lives exclusively in
``transactions``.
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.time import utc_now_naive
from app.database.mysql.session import SessionLocal
from app.repositories import voice_command_repository

logger = logging.getLogger(__name__)

VOICE_COMMAND_SOURCE = "android_speech_recognizer"


def record_voice_command(
    *,
    user_id: int,
    request_id: str,
    voice_text: str,
    parser_confidence: float | None = None,
    transaction_id: int | None = None,
    nlp_metadata: dict[str, Any] | None = None,
) -> None:
    """Store one confirmed voice command per (user, request).

    A retry with the same ``request_id`` creates no duplicate and leaves the
    first row untouched. Failures are logged, never raised.
    """

    try:
        with SessionLocal() as db:
            voice_command_repository.record_once(
                db,
                user_id=user_id,
                request_id=request_id,
                voice_text=voice_text,
                parser_confidence=parser_confidence,
                transaction_id=transaction_id,
                nlp=nlp_metadata or {},
                source=VOICE_COMMAND_SOURCE,
                created_at=utc_now_naive(),
            )
            db.commit()
    except Exception as exc:  # best effort by contract
        logger.error("Voice command metadata was not persisted: %s", exc)
