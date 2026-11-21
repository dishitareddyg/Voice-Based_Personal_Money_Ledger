"""Persistence for ``EXCHANGE_RATE_CACHE``. Callers own session and commit."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.orm import Session

from app.models.exchange_rate_cache import ExchangeRateCache


def get_valid_rate(
    db: Session, base: str, target: str, now: datetime
) -> Decimal | None:
    """Return the cached rate if it has not expired (``valid_until > now``)."""

    value = db.scalar(
        select(ExchangeRateCache.rate)
        .where(
            ExchangeRateCache.base_currency == base,
            ExchangeRateCache.target_currency == target,
            ExchangeRateCache.valid_until > now,
        )
        .order_by(ExchangeRateCache.valid_until.desc())
        .limit(1)
    )
    return None if value is None else Decimal(value)


def upsert_rate(
    db: Session,
    *,
    base: str,
    target: str,
    rate: Decimal,
    provider: str,
    retrieved_at: datetime,
    valid_until: datetime,
) -> None:
    """Atomically insert or refresh the single row for a currency pair."""

    stmt = mysql_insert(ExchangeRateCache.__table__).values(
        base_currency=base,
        target_currency=target,
        rate=rate,
        provider=provider,
        retrieved_at=retrieved_at,
        valid_until=valid_until,
    )
    db.execute(
        stmt.on_duplicate_key_update(
            rate=rate,
            provider=provider,
            retrieved_at=retrieved_at,
            valid_until=valid_until,
        )
    )


def delete_expired(db: Session, now: datetime) -> int:
    result = db.execute(
        delete(ExchangeRateCache).where(ExchangeRateCache.valid_until < now)
    )
    return int(result.rowcount or 0)


def count(db: Session) -> int:
    return int(db.scalar(select(func.count(ExchangeRateCache.id))) or 0)
