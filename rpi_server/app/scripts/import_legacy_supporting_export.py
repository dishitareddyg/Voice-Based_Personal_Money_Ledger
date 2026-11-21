"""Import supporting rows from a legacy document-store JSON Lines export.

The pre-MySQL deployment stored voice metadata, audit records, application
events and the FX cache outside the relational database. This script reads a
plain JSON Lines export (one document per line) and writes the four MySQL
supporting tables. It never needs a document-database driver and it never
touches the financial tables.

Expected files in ``--source-dir``:

    voice_commands.jsonl
    audit_logs.jsonl
    application_events.jsonl
    exchange_rates.jsonl

Usage (from ``rpi_server`` after ``alembic upgrade head``):

    python -m app.scripts.import_legacy_supporting_export \
        --source-dir /var/backups/voice_ledger/legacy_export

The import is resumable: voice commands and FX rates are upserted by their
natural keys, while audit and application rows are de-duplicated on
``(event_type, request_id, user_id, created_at)``.
"""

from __future__ import annotations

import argparse
import json
import logging
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.time import utc_now_naive
from app.database.mysql.session import SessionLocal
from app.models.application_event import ApplicationEvent
from app.models.audit_log import AuditLog
from app.models.user import User
from app.repositories import (
    audit_repository,
    exchange_rate_repository,
    voice_command_repository,
)

logger = logging.getLogger(__name__)


def _parse_datetime(value: object) -> datetime:
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, dict) and "$date" in value:
        return _parse_datetime(value["$date"])
    elif isinstance(value, dict) and "$numberLong" in value:
        parsed = datetime.fromtimestamp(
            int(value["$numberLong"]) / 1000, tz=timezone.utc
        )
    else:
        text = str(value)
        if text.endswith("Z"):
            text = f"{text[:-1]}+00:00"
        parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed


def coerce_extended_json(value: Any) -> Any:
    """Convert common extended-JSON wrappers without importing a BSON library."""

    if isinstance(value, dict):
        if "$date" in value:
            return _parse_datetime(value)
        if "$numberDecimal" in value:
            return Decimal(str(value["$numberDecimal"]))
        if "$numberLong" in value:
            return int(value["$numberLong"])
        if "$numberInt" in value:
            return int(value["$numberInt"])
        if "$oid" in value:
            return str(value["$oid"])
        return {key: coerce_extended_json(item) for key, item in value.items()}
    if isinstance(value, list):
        return [coerce_extended_json(item) for item in value]
    return value


def _read_records(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        logger.warning("Skipping missing export file: %s", path)
        return []
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            text = line.strip()
            if not text:
                continue
            try:
                payload = json.loads(text)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"{path.name}:{line_number} is not valid JSON"
                ) from exc
            if isinstance(payload, list):
                records.extend(coerce_extended_json(item) for item in payload)
            else:
                records.append(coerce_extended_json(payload))
    return records


def _user_exists(db: Session, user_id: int | None) -> bool:
    if user_id is None:
        return True
    return db.get(User, user_id) is not None


def _audit_row_exists(
    db: Session,
    model: type[AuditLog] | type[ApplicationEvent],
    *,
    event_type: str,
    request_id: str | None,
    user_id: int | None,
    created_at: datetime,
) -> bool:
    return (
        db.scalar(
            select(model.id).where(
                model.event_type == event_type,
                model.request_id.is_(None)
                if request_id is None
                else model.request_id == request_id,
                model.user_id.is_(None)
                if user_id is None
                else model.user_id == user_id,
                model.created_at == created_at,
            )
        )
        is not None
    )


def _import_voice_commands(db: Session, records: list[dict[str, Any]]) -> int:
    imported = 0
    for record in records:
        user_id = int(record["user_id"])
        if not _user_exists(db, user_id):
            logger.warning("Voice command skipped: unknown user %s", user_id)
            continue
        voice_command_repository.upsert(
            db,
            user_id=user_id,
            request_id=str(record["request_id"]),
            voice_text=str(record.get("voice_text") or ""),
            parser_confidence=record.get("parser_confidence"),
            transaction_id=record.get("transaction_id"),
            nlp_metadata=record.get("nlp"),
            source=str(
                record.get("source") or "android_speech_recognizer"
            ),
            created_at=_parse_datetime(
                record.get("created_at") or utc_now_naive()
            ),
        )
        imported += 1
    return imported


def _import_audit_rows(
    db: Session,
    records: list[dict[str, Any]],
    model: type[AuditLog] | type[ApplicationEvent],
    add,
) -> int:
    imported = 0
    for record in records:
        user_id = record.get("user_id")
        user_id = int(user_id) if user_id is not None else None
        if not _user_exists(db, user_id):
            logger.warning("%s skipped: unknown user %s", model.__name__, user_id)
            continue
        event_type = str(record.get("event_type") or "legacy_event")
        request_id = record.get("request_id")
        request_id = str(request_id) if request_id is not None else None
        created_at = _parse_datetime(
            record.get("created_at") or utc_now_naive()
        )
        if _audit_row_exists(
            db,
            model,
            event_type=event_type,
            request_id=request_id,
            user_id=user_id,
            created_at=created_at,
        ):
            continue
        add(
            db,
            event_type=event_type,
            user_id=user_id,
            request_id=request_id,
            created_at=created_at,
            ip_address=record.get("ip_address"),
            user_agent=record.get("user_agent"),
            payload=record.get("payload"),
        )
        imported += 1
    return imported


def _import_exchange_rates(
    db: Session, records: list[dict[str, Any]]
) -> int:
    imported = 0
    for record in records:
        retrieved_at = _parse_datetime(
            record.get("retrieved_at") or utc_now_naive()
        )
        valid_until = _parse_datetime(
            record.get("valid_until") or retrieved_at
        )
        if valid_until <= retrieved_at:
            logger.warning("FX rate skipped: invalid validity window")
            continue
        exchange_rate_repository.upsert(
            db,
            base_currency=str(record["base_currency"]).upper(),
            target_currency=str(record["target_currency"]).upper(),
            rate=Decimal(str(record["rate"])),
            provider=str(record.get("provider") or "legacy-import"),
            retrieved_at=retrieved_at,
            valid_until=valid_until,
        )
        imported += 1
    return imported


def import_export(source_dir: Path) -> dict[str, int]:
    results: dict[str, int] = {}
    with SessionLocal() as db:
        results["voice_commands"] = _import_voice_commands(
            db, _read_records(source_dir / "voice_commands.jsonl")
        )
        db.commit()
        results["audit_logs"] = _import_audit_rows(
            db,
            _read_records(source_dir / "audit_logs.jsonl"),
            AuditLog,
            audit_repository.add_audit_log,
        )
        db.commit()
        results["application_events"] = _import_audit_rows(
            db,
            _read_records(source_dir / "application_events.jsonl"),
            ApplicationEvent,
            audit_repository.add_application_event,
        )
        db.commit()
        results["exchange_rates"] = _import_exchange_rates(
            db, _read_records(source_dir / "exchange_rates.jsonl")
        )
        db.commit()
    return results


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Import legacy supporting documents into the MySQL "
            "VOICE_COMMAND, AUDIT_LOG, APPLICATION_EVENT and "
            "EXCHANGE_RATE_CACHE tables."
        )
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("legacy_export"),
        help="Directory containing the four JSONL export files.",
    )
    parser.add_argument(
        "--log-level", default="INFO", help="Python logging level."
    )
    args = parser.parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper(), logging.INFO))
    results = import_export(args.source_dir)
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
