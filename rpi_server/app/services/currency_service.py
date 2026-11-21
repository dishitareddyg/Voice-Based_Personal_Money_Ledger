from __future__ import annotations

import logging
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

import httpx
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import get_settings
from app.core.enums import ErrorCode
from app.core.errors import AppError
from app.core.time import utc_now_naive
from app.database.mysql.session import SessionLocal
from app.models.exchange_rate_cache import RATE_PRECISION, RATE_SCALE
from app.repositories import exchange_rate_repository

logger = logging.getLogger(__name__)

_RATE_QUANTUM = Decimal(1).scaleb(-RATE_SCALE)
_RATE_LIMIT = Decimal(10) ** (RATE_PRECISION - RATE_SCALE)


def _normalise_rate(rate: Decimal) -> Decimal | None:
    """Round to the stored scale; None if unusable (non-finite, <=0, huge)."""
    if not rate.is_finite() or rate <= 0 or rate >= _RATE_LIMIT:
        return None
    rate = rate.quantize(_RATE_QUANTUM, rounding=ROUND_HALF_UP)
    return rate if rate > 0 else None


def _read_cache(base: str, target: str) -> Decimal | None:
    try:
        with SessionLocal() as db:
            rate = exchange_rate_repository.get_valid_rate(
                db, base, target, utc_now_naive()
            )
    except SQLAlchemyError as exc:  # cache is optional; provider is canonical
        logger.warning("Exchange-rate cache unavailable: %s", exc)
        return None
    if rate is None or not rate.is_finite() or rate <= 0:
        return None
    return rate


def _write_cache(
    base: str, target: str, rate: Decimal, provider: str
) -> None:
    settings = get_settings()
    now = utc_now_naive()
    try:
        with SessionLocal() as db:
            exchange_rate_repository.upsert_rate(
                db,
                base=base,
                target=target,
                rate=rate,
                provider=provider[:255],
                retrieved_at=now,
                valid_until=now
                + timedelta(minutes=settings.exchange_rate_cache_minutes),
            )
            db.commit()
    except SQLAlchemyError as exc:
        logger.warning("Could not cache exchange rate: %s", exc)


def _fetch_rate(base: str, target: str) -> Decimal:
    settings = get_settings()
    url = f"{settings.exchange_rate_base_url.rstrip('/')}/{base}"
    try:
        with httpx.Client(
            timeout=settings.exchange_rate_timeout_seconds
        ) as client:
            response = client.get(url)
            response.raise_for_status()
            payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise AppError(
            ErrorCode.EXCHANGE_RATE_UNAVAILABLE,
            "A live exchange rate is unavailable right now. "
            "Please enter the amount in INR or try again shortly.",
            status_code=503,
        ) from exc

    rates = payload.get("rates") if isinstance(payload, dict) else None
    raw_rate = rates.get(target) if isinstance(rates, dict) else None
    if raw_rate is None:
        raise AppError(
            ErrorCode.EXCHANGE_RATE_UNAVAILABLE,
            f"No exchange rate is available for {base} to {target}.",
            status_code=503,
        )
    try:
        parsed = Decimal(str(raw_rate))
    except (ValueError, ArithmeticError) as exc:
        raise AppError(
            ErrorCode.EXCHANGE_RATE_UNAVAILABLE,
            "The exchange-rate provider returned an invalid rate.",
            status_code=503,
        ) from exc
    rate = _normalise_rate(parsed)
    if rate is None:
        raise AppError(
            ErrorCode.EXCHANGE_RATE_UNAVAILABLE,
            "The exchange-rate provider returned an invalid rate.",
            status_code=503,
        )
    return rate


def get_rate(base: str, target: str = "INR") -> Decimal:
    base = base.strip().upper()
    target = target.strip().upper()
    if base == target:
        return Decimal("1")
    cached = _read_cache(base, target)
    if cached is not None:
        return cached
    rate = _fetch_rate(base, target)
    provider = get_settings().exchange_rate_base_url
    _write_cache(base, target, rate, provider)
    return rate
