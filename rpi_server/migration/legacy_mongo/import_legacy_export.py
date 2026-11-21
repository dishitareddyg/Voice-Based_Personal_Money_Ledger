"""One-off import of legacy document-store exports into MySQL.

This is a standalone migration tool. It is NOT part of the application, is
never imported by it, and needs neither PyMongo nor BSON: it reads the
newline-delimited Extended JSON files produced by the ``mongoexport`` command
line tool (see README.md in this folder).

    python migration/legacy_mongo/import_legacy_export.py \
        --dir /path/to/export [--dry-run]

Expected files in --dir (any may be missing):
    voice_commands.jsonl  audit_logs.jsonl
    application_events.jsonl  exchange_rates.jsonl

Nothing is silently dropped:
  * re-running is safe (voice commands and rates use their unique keys; audit
    and event rows are skipped when an identical row already exists);
  * audit/event rows whose user no longer exists are imported with
    user_id NULL and the old id preserved in payload._legacy_user_id;
  * voice commands for a missing user cannot satisfy the foreign key; they
    are written to rejected_voice_commands.jsonl for manual review;
  * a missing transaction reference is set to NULL and preserved in
    nlp._legacy_transaction_id;
  * every skipped/rejected row is counted in the final report.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from sqlalchemy import select, text  # noqa: E402

from app.database.mysql.session import SessionLocal  # noqa: E402
from app.models.application_event import ApplicationEvent  # noqa: E402
from app.models.audit_log import AuditLog  # noqa: E402
from app.models.transaction import Transaction  # noqa: E402
from app.models.user import User  # noqa: E402
from app.repositories import (  # noqa: E402
    audit_repository,
    exchange_rate_repository,
    voice_command_repository,
)


def plain(value: Any) -> Any:
    """Convert MongoDB Extended JSON (relaxed or canonical) to plain Python."""
    if isinstance(value, list):
        return [plain(v) for v in value]
    if isinstance(value, dict):
        if len(value) == 1:
            (key, inner), = value.items()
            if key == "$date":
                if isinstance(inner, dict):  # canonical: {"$numberLong": ms}
                    inner = int(plain(inner))
                    return datetime.fromtimestamp(
                        inner / 1000, tz=timezone.utc
                    ).replace(tzinfo=None)
                if isinstance(inner, (int, float)):
                    return datetime.fromtimestamp(
                        inner / 1000, tz=timezone.utc
                    ).replace(tzinfo=None)
                parsed = datetime.fromisoformat(inner.replace("Z", "+00:00"))
                if parsed.tzinfo is not None:
                    parsed = parsed.astimezone(timezone.utc).replace(
                        tzinfo=None
                    )
                return parsed
            if key == "$numberDecimal":
                return Decimal(inner)
            if key in ("$numberLong", "$numberInt"):
                return int(inner)
            if key == "$numberDouble":
                return float(inner)
            if key == "$oid":
                return inner
        return {k: plain(v) for k, v in value.items()}
    return value


def read_jsonl(path: Path):
    if not path.exists():
        return
    with path.open(encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            line = line.strip()
            if line:
                try:
                    yield number, plain(json.loads(line))
                except (ValueError, InvalidOperation) as exc:
                    raise SystemExit(f"{path.name}:{number}: bad JSON: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dir", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    stats: dict[str, int] = {}

    def bump(key: str) -> None:
        stats[key] = stats.get(key, 0) + 1

    with SessionLocal() as db:
        users = set(db.scalars(select(User.id)))
        transactions = set(db.scalars(select(Transaction.id)))
        rejected = args.dir / "rejected_voice_commands.jsonl"
        rejected_rows: list[dict[str, Any]] = []

        for _, doc in read_jsonl(args.dir / "voice_commands.jsonl"):
            if doc.get("user_id") not in users:
                bump("voice_commands.rejected_missing_user")
                rejected_rows.append(doc)
                continue
            nlp = dict(doc.get("nlp") or {})
            tx_id = doc.get("transaction_id")
            if tx_id is not None and tx_id not in transactions:
                nlp["_legacy_transaction_id"] = tx_id
                tx_id = None
                bump("voice_commands.transaction_unlinked")
            voice_command_repository.record_once(
                db,
                user_id=doc["user_id"],
                request_id=doc["request_id"],
                voice_text=doc.get("voice_text") or "",
                parser_confidence=doc.get("parser_confidence"),
                transaction_id=tx_id,
                nlp=nlp,
                source=doc.get("source") or "android_speech_recognizer",
                created_at=doc["created_at"],
            )
            bump("voice_commands.processed")

        for name, model, add in (
            ("audit_logs", AuditLog, audit_repository.add_audit_log),
            (
                "application_events",
                ApplicationEvent,
                audit_repository.add_application_event,
            ),
        ):
            for _, doc in read_jsonl(args.dir / f"{name}.jsonl"):
                payload = doc.get("payload")
                user_id = doc.get("user_id")
                if user_id is not None and user_id not in users:
                    payload = dict(payload or {})
                    payload["_legacy_user_id"] = user_id
                    user_id = None
                    bump(f"{name}.user_unlinked")
                request_id = doc.get("request_id")
                clause = [
                    model.event_type == doc["event_type"],
                    model.created_at == doc["created_at"],
                    model.user_id.is_(None)
                    if user_id is None
                    else model.user_id == user_id,
                    model.request_id.is_(None)
                    if request_id is None
                    else model.request_id == request_id,
                ]
                if db.scalar(select(model.id).where(*clause).limit(1)):
                    bump(f"{name}.already_present")
                    continue
                add(
                    db,
                    event_type=doc["event_type"],
                    user_id=user_id,
                    request_id=request_id,
                    payload=payload,
                    ip_address=doc.get("ip_address"),
                    user_agent=doc.get("user_agent"),
                    created_at=doc["created_at"],
                )
                bump(f"{name}.imported")

        for _, doc in read_jsonl(args.dir / "exchange_rates.jsonl"):
            exchange_rate_repository.upsert_rate(
                db,
                base=doc["base_currency"],
                target=doc["target_currency"],
                rate=Decimal(str(doc["rate"])),
                provider=doc.get("provider") or "legacy-import",
                retrieved_at=doc["retrieved_at"],
                valid_until=doc["valid_until"],
            )
            bump("exchange_rates.processed")

        if args.dry_run:
            db.rollback()
        else:
            db.commit()
            if rejected_rows:
                with rejected.open("w", encoding="utf-8") as handle:
                    for row in rejected_rows:
                        handle.write(json.dumps(row, default=str) + "\n")
        db.execute(text("SELECT 1"))

    print("DRY RUN (nothing committed)" if args.dry_run else "Committed.")
    for key in sorted(stats):
        print(f"  {key}: {stats[key]}")
    if rejected_rows and not args.dry_run:
        print(f"  rejected rows saved to {rejected}")


if __name__ == "__main__":
    main()
