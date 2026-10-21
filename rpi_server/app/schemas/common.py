"""Shared Pydantic primitives."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer

from app.core.time import to_utc_iso


def _serialize_utc(value: datetime | None) -> str | None:
    return to_utc_iso(value)


UtcDateTime = Annotated[
    datetime,
    PlainSerializer(_serialize_utc, return_type=str | None, when_used="json"),
]

# Amounts are validated by business rules so the API can return INVALID_AMOUNT
# instead of a generic schema error. The column limits are still enforced.
AmountInput = Annotated[Decimal, Field(max_digits=15, decimal_places=2)]
RateInput = Annotated[Decimal, Field(ge=0, le=100, max_digits=6, decimal_places=3)]


class APIModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
        str_strip_whitespace=True,
    )


class ErrorResponse(APIModel):
    success: bool = False
    error_code: str
    message: str
    request_id: str | None = None
    details: dict[str, Any] | None = None
