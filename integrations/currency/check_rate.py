#!/usr/bin/env python3
"""Verify the Pi's live FX provider and MongoDB rate cache.

Run this from ``rpi_server`` so the application's ``.env`` is loaded:

    .venv/bin/python ../integrations/currency/check_rate.py USD

It calls the same ``currency_service`` used by financial writes, so a success
here proves the provider path and cache document are working.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

from bson.decimal128 import Decimal128
from pymongo.errors import PyMongoError

REPO_ROOT = Path(__file__).resolve().parents[2]
SERVER_ROOT = REPO_ROOT / "rpi_server"
if str(SERVER_ROOT) not in sys.path:
    sys.path.insert(0, str(SERVER_ROOT))

from app.core.config import get_settings  # noqa: E402
from app.core.errors import AppError  # noqa: E402
from app.database.mongodb.client import get_mongo_database  # noqa: E402
from app.services import currency_service  # noqa: E402

_CACHE_COLLECTION = "exchange_rates"


def _jsonable(value: Any) -> Any:
    if isinstance(value, Decimal128):
        return format(value.to_decimal(), "f")
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {key: _jsonable(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_jsonable(item) for item in value]
    return value


def _cache_document(base: str, target: str) -> tuple[dict | None, str | None]:
    try:
        document = get_mongo_database().database[_CACHE_COLLECTION].find_one(
            {"base_currency": base, "target_currency": target},
            sort=[("retrieved_at", -1)],
        )
    except PyMongoError as exc:
        return None, str(exc)
    if document is None:
        return None, "No cache document was written."
    document.pop("_id", None)
    return document, None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check a live exchange rate and its MongoDB cache entry."
    )
    parser.add_argument("base", nargs="?", default="USD")
    parser.add_argument("--target", default="INR")
    args = parser.parse_args()

    base = args.base.strip().upper()
    target = args.target.strip().upper()
    if len(base) != 3 or len(target) != 3:
        parser.error("currencies must be three-letter ISO codes")

    result: dict[str, Any] = {
        "base_currency": base,
        "target_currency": target,
        "provider_url": get_settings().exchange_rate_base_url,
    }
    try:
        rate = currency_service.get_rate(base, target)
    except AppError as exc:
        result.update(
            {
                "ok": False,
                "error_code": exc.code.value,
                "message": exc.message,
            }
        )
        print(json.dumps(result, indent=2))
        return 2

    document, cache_error = _cache_document(base, target)
    result.update(
        {
            "ok": True,
            "rate": _jsonable(rate),
            "cache": _jsonable(document),
            "cache_error": cache_error,
        }
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
