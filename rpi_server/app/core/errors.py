"""Domain errors with machine-readable codes."""

from __future__ import annotations

from typing import Any

from app.core.enums import ErrorCode


class AppError(Exception):
    def __init__(
        self,
        code: ErrorCode,
        message: str,
        *,
        status_code: int = 400,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details


def error_payload(
    code: ErrorCode,
    message: str,
    *,
    details: dict[str, Any] | None = None,
    request_id: str | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "success": False,
        "error_code": code.value,
        "message": message,
        "request_id": request_id,
    }
    if details:
        payload["details"] = details
    return payload
