"""Timezone helpers.

MySQL stores UTC timestamps. The user's intended financial date is stored
separately as a DATE so it is never shifted by a timezone conversion.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone, tzinfo
from zoneinfo import ZoneInfo

from app.core.config import get_settings

try:
    IST: tzinfo = ZoneInfo("Asia/Kolkata")
except Exception:  # Windows without the optional tzdata package
    IST = timezone(timedelta(hours=5, minutes=30))


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def utc_now_naive() -> datetime:
    """Naive UTC value suitable for MySQL DATETIME columns."""
    return utc_now().replace(tzinfo=None)


def timezone_for(name: str | None) -> tzinfo:
    try:
        return ZoneInfo(name or get_settings().default_timezone)
    except Exception:  # pragma: no cover - invalid tz falls back safely
        return IST


def today_in_timezone(name: str | None = None) -> date:
    return datetime.now(timezone_for(name)).date()


def ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def to_utc_iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return ensure_utc(value).isoformat().replace("+00:00", "Z")
