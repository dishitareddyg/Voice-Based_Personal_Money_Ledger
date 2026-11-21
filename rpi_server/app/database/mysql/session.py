"""SQLAlchemy engine and session factory for MySQL 8.x."""

from __future__ import annotations

import json
from collections.abc import Iterator
from typing import Any

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings

_settings = get_settings()


def _json_dumps(value: Any) -> str:
    """Serialise JSON columns; Decimal/datetime/UUID values become strings."""
    return json.dumps(value, default=str, ensure_ascii=False)


engine = create_engine(
    _settings.sqlalchemy_url,
    pool_pre_ping=True,
    pool_recycle=280,
    pool_size=_settings.db_pool_size,
    max_overflow=_settings.db_max_overflow,
    json_serializer=_json_dumps,
    echo=False,
    future=True,
)

SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


def get_db() -> Iterator[Session]:
    """FastAPI dependency: one session per request, rolled back on error."""
    session = SessionLocal()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def dispose_engine() -> None:
    """Close pooled connections (application shutdown)."""
    engine.dispose()
