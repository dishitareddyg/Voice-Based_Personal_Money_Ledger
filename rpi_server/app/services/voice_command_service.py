"""Voice command metadata in MongoDB.

Only confirmed text is stored. Audio never reaches the server. This collection
keeps the original transcript, parser confidence and extraction metadata for
analytics and evaluation; the financial effect lives exclusively in MySQL.
"""

from __future__ import annotations

import logging
from typing import Any

from pymongo.errors import PyMongoError

from app.core.time import utc_now
from app.database.mongodb.client import get_mongo_database

logger = logging.getLogger(__name__)

VOICE_COMMAND_COLLECTION = "voice_commands"


def record_voice_command(
    *,
    user_id: int,
    request_id: str,
    voice_text: str,
    parser_confidence: float | None = None,
    transaction_id: int | None = None,
    nlp_metadata: dict[str, Any] | None = None,
) -> None:
    """Upsert one confirmed voice command per (user, request).

    A retry with the same ``request_id`` must not create a duplicate document.
    """

    document: dict[str, Any] = {
        "user_id": user_id,
        "request_id": request_id,
        "voice_text": voice_text,
        "parser_confidence": parser_confidence,
        "transaction_id": transaction_id,
        "nlp": nlp_metadata or {},
        "source": "android_speech_recognizer",
        "created_at": utc_now(),
    }
    try:
        get_mongo_database().database[VOICE_COMMAND_COLLECTION].update_one(
            {"user_id": user_id, "request_id": request_id},
            {"$setOnInsert": document},
            upsert=True,
        )
    except PyMongoError as exc:
        logger.error("Voice command metadata was not persisted: %s", exc)
