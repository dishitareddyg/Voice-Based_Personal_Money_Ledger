"""Per-request correlation id propagated to logs and error responses."""

from __future__ import annotations

from contextvars import ContextVar
from uuid import uuid4

_request_id: ContextVar[str | None] = ContextVar("request_id", default=None)


def set_request_id(value: str | None = None) -> str:
    request_id = value or uuid4().hex
    _request_id.set(request_id)
    return request_id


def get_request_id() -> str | None:
    return _request_id.get()
