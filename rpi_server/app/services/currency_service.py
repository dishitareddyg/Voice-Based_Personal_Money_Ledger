from __future__ import annotations

import logging
from datetime import timedelta
from decimal import Decimal

import httpx
from bson.decimal128 import Decimal128
from pymongo.errors import PyMongoError

from app.core.config import get_settings
from app.core.enums import ErrorCode
from app.core.errors import AppError
from app.core.time import utc_now
from app.database.mongodb.client import get_mongo_database

logger = logging.getLogger(__name__)

_COLLECTION = "exchange_rates"


def _as_decimal(value: object) -> Decimal:
    if isinstance(value, Decimal128):
        return value.to_decimal()
    return Decimal(str(value))


def _collection():
    return get_mongo_database().database[_COLLECTION]


def _read_cache(base: str, target: str) -> Decimal | None:
    try:
        document = _collection().find_one(
            {
                "base_currency": base,
                "target_currency": target,
                "valid_until": {"$gt": utc_now()},
            },
            sort=[("valid_until", -1)],
        )
    except PyMongoError as exc:  # cache is optional; the provider is canonical
        logger.warning("Exchange-rate cache unavailable: %s", exc)
        return None
    if not document:
        return None
    try:
        rate = _as_decimal(document["rate"])
    except (KeyError, ValueError):
        return None
    return rate if rate > 0 else None


def _write_cache(
    base: str, target: str, rate: Decimal, provider: str
) -> None:
    settings = get_settings()
    now = utc_now()
    try:
        _collection().update_one(
            {"base_currency": base, "target_currency": target},
            {
                "$set": {
                    "base_currency": base,
                    "target_currency": target,
                    "rate": Decimal128(rate),
                    "provider": provider,
                    "retrieved_at": now,
                    "valid_until": now
                    + timedelta(minutes=settings.exchange_rate_cache_minutes),
                }
            },
            upsert=True,
        )
    except PyMongoError as exc:
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
        rate = Decimal(str(raw_rate))
    except (ValueError, ArithmeticError) as exc:
        raise AppError(
            ErrorCode.EXCHANGE_RATE_UNAVAILABLE,
            "The exchange-rate provider returned an invalid rate.",
            status_code=503,
        ) from exc
    if rate <= 0:
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
