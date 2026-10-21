from __future__ import annotations

import logging
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from sqlalchemy import func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.enums import AdminAction, ErrorCode
from app.core.errors import AppError
from app.core.security import verify_password
from app.core.time import utc_now
from app.database.mongodb.client import get_mongo_database
from app.models.category import Category
from app.models.interest_scheme import InterestScheme
from app.models.loan import Loan
from app.models.person import Person
from app.models.repayment import Repayment
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.admin import AdminActionRequest, AdminActionResponse
from app.services import audit_service

logger = logging.getLogger(__name__)

_OPTIMIZE_TABLES = (
    "users",
    "persons",
    "categories",
    "loans",
    "transactions",
    "repayments",
)

_MESSAGE = {
    AdminAction.DATABASE_STATS: "Database statistics collected.",
    AdminAction.RUN_MIGRATIONS: "Database migrations are up to date.",
    AdminAction.CREATE_BACKUP: "Backup created successfully.",
    AdminAction.OPTIMIZE_INDEXES: "Index statistics refreshed.",
    AdminAction.PRUNE_RATE_CACHE: "Expired exchange-rate cache pruned.",
}


def run_action(
    db: Session,
    admin: User,
    payload: AdminActionRequest,
    *,
    ip_address: str | None = None,
) -> AdminActionResponse:
    if not admin.is_admin:
        raise AppError(
            ErrorCode.FORBIDDEN,
            "Administrator access is required.",
            status_code=403,
        )
    if not verify_password(payload.password, admin.password_hash):
        raise AppError(
            ErrorCode.ADMIN_PASSWORD_INVALID,
            "Administrator password is incorrect.",
            status_code=403,
        )
    if not payload.confirm:
        raise AppError(
            ErrorCode.ADMIN_CONFIRMATION_REQUIRED,
            "This action must be explicitly confirmed.",
            status_code=400,
        )

    action = payload.action
    if action is AdminAction.DATABASE_STATS:
        details = _database_stats(db)
    elif action is AdminAction.RUN_MIGRATIONS:
        details = _run_migrations(db)
    elif action is AdminAction.CREATE_BACKUP:
        details = _create_backup(db)
    elif action is AdminAction.OPTIMIZE_INDEXES:
        details = _optimize_indexes(db)
    elif action is AdminAction.PRUNE_RATE_CACHE:
        details = _prune_rate_cache()
    else:  # pragma: no cover - enum makes this unreachable
        raise AppError(
            ErrorCode.UNSUPPORTED_ACTION,
            "Unsupported administrative action.",
            status_code=400,
        )

    audit_service.record_event(
        "admin_action",
        user_id=admin.id,
        payload={"action": action.value},
        ip_address=ip_address,
    )
    audit_service.record_application_event(
        "admin_action_completed",
        user_id=admin.id,
        payload={"action": action.value},
        ip_address=ip_address,
    )
    return AdminActionResponse(
        action=action,
        message=_MESSAGE[action],
        completed_at=utc_now(),
        details=details,
    )


def _database_stats(db: Session) -> dict[str, object]:
    counts: dict[str, int] = {}
    for name, model in (
        ("users", User),
        ("persons", Person),
        ("categories", Category),
        ("loans", Loan),
        ("transactions", Transaction),
        ("repayments", Repayment),
        ("interest_schemes", InterestScheme),
    ):
        counts[name] = int(
            db.scalar(select(func.count()).select_from(model)) or 0
        )

    try:
        version = str(db.scalar(text("SELECT VERSION()")) or "unknown")
        database_name = str(db.scalar(text("SELECT DATABASE()")) or "unknown")
        table_rows = db.execute(
            text(
                "SELECT table_name, table_rows, "
                "ROUND((data_length + index_length) / 1024 / 1024, 2) "
                "FROM information_schema.tables "
                "WHERE table_schema = DATABASE() "
                "ORDER BY table_name"
            )
        ).all()
    except Exception as exc:  # statistics are informational
        logger.warning("Could not read MySQL statistics: %s", exc)
        version = "unavailable"
        database_name = "unavailable"
        table_rows = []

    tables = [
        {
            "table": str(row[0]),
            "rows": int(row[1] or 0),
            "size_mb": float(row[2] or 0),
        }
        for row in table_rows
    ]

    mongo: dict[str, object] = {}
    try:
        database = get_mongo_database().database
        mongo = {
            "voice_commands": int(
                database["voice_commands"].estimated_document_count()
            ),
            "audit_logs": int(
                database["audit_logs"].estimated_document_count()
            ),
            "exchange_rates": int(
                database["exchange_rates"].estimated_document_count()
            ),
            "application_events": int(
                database["application_events"].estimated_document_count()
            ),
        }
    except Exception as exc:
        logger.warning("Could not read MongoDB statistics: %s", exc)
        mongo = {"status": "unavailable"}

    return {
        "mysql_version": version,
        "database": database_name,
        "counts": counts,
        "tables": tables,
        "mongodb": mongo,
    }


def _run_migrations(db: Session) -> dict[str, object]:
    settings = get_settings()
    config_path = Path(settings.alembic_config_path)
    if not config_path.is_absolute():
        config_path = Path(settings.project_root) / config_path
    if not config_path.exists():
        raise AppError(
            ErrorCode.SERVICE_UNAVAILABLE,
            "Alembic configuration was not found on the server.",
            status_code=503,
        )

    db.commit()  # release the connection before another process runs DDL
    try:
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "alembic",
                "-c",
                str(config_path),
                "upgrade",
                "head",
            ],
            cwd=str(settings.project_root),
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise AppError(
            ErrorCode.DATABASE_ERROR,
            "Could not run database migrations.",
            status_code=500,
        ) from exc

    if result.returncode != 0:
        logger.error("alembic upgrade failed: %s", result.stderr[-2000:])
        raise AppError(
            ErrorCode.DATABASE_ERROR,
            "Database migrations failed. Check the server logs.",
            status_code=500,
        )

    return {
        "return_code": result.returncode,
        "output_tail": (result.stdout or "")[-2000:],
    }


def _create_backup(db: Session) -> dict[str, object]:
    settings = get_settings()
    mysqldump = shutil.which("mysqldump")
    if not mysqldump:
        raise AppError(
            ErrorCode.SERVICE_UNAVAILABLE,
            "mysqldump is not installed on the server.",
            status_code=503,
        )

    url = make_url(settings.sqlalchemy_url)
    if not url.database:
        raise AppError(
            ErrorCode.SERVICE_UNAVAILABLE,
            "Database name is not configured.",
            status_code=503,
        )

    backup_dir = Path(settings.backup_dir)
    try:
        backup_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise AppError(
            ErrorCode.SERVICE_UNAVAILABLE,
            "The backup directory is not writable.",
            status_code=503,
        ) from exc

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    destination = backup_dir / f"voice_ledger_{timestamp}.sql"

    command = [
        mysqldump,
        "--host",
        url.host or "127.0.0.1",
        "--port",
        str(url.port or 3306),
        "--user",
        url.username or "root",
        "--single-transaction",
        "--quick",
        "--routines",
        "--triggers",
        "--no-tablespaces",
        "--default-character-set=utf8mb4",
        str(url.database),
    ]
    environment = os.environ.copy()
    if url.password:
        environment["MYSQL_PWD"] = url.password

    db.commit()
    try:
        with destination.open("wb") as handle:
            result = subprocess.run(
                command,
                stdout=handle,
                stderr=subprocess.PIPE,
                env=environment,
                timeout=300,
                check=False,
            )
    except (OSError, subprocess.SubprocessError) as exc:
        destination.unlink(missing_ok=True)
        raise AppError(
            ErrorCode.DATABASE_ERROR,
            "Could not create the database backup.",
            status_code=500,
        ) from exc

    if result.returncode != 0:
        destination.unlink(missing_ok=True)
        logger.error(
            "mysqldump failed: %s",
            result.stderr.decode(errors="replace")[-2000:],
        )
        raise AppError(
            ErrorCode.DATABASE_ERROR,
            "Could not create the database backup.",
            status_code=500,
        )

    return {
        "path": str(destination),
        "size_bytes": destination.stat().st_size,
        "created_at": timestamp,
    }


def _optimize_indexes(db: Session) -> dict[str, object]:
    results: list[dict[str, object]] = []
    for table in _OPTIMIZE_TABLES:
        rows = db.execute(text(f"ANALYZE TABLE `{table}`")).all()
        for row in rows:
            results.append(
                {
                    "table": str(row[0]),
                    "op": str(row[1]),
                    "msg_type": str(row[2]),
                    "msg_text": str(row[3]),
                }
            )
    db.commit()
    return {"tables": results}


def _prune_rate_cache() -> dict[str, object]:
    try:
        result = get_mongo_database().database[
            "exchange_rates"
        ].delete_many({"valid_until": {"$lt": utc_now()}})
    except Exception as exc:
        raise AppError(
            ErrorCode.SERVICE_UNAVAILABLE,
            "The exchange-rate cache could not be pruned.",
            status_code=503,
        ) from exc
    return {"deleted": int(result.deleted_count)}
