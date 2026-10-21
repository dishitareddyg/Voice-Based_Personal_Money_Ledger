from __future__ import annotations

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.enums import ErrorCode
from app.core.errors import AppError
from app.core.security import decode_access_token
from app.database.mysql.session import get_db
from app.models.user import User
from app.repositories import user_repository

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(
            ErrorCode.UNAUTHORIZED,
            "Authentication is required.",
            status_code=401,
        )
    payload = decode_access_token(credentials.credentials)
    raw_id = payload.get("sub")
    try:
        user_id = int(str(raw_id))
    except (TypeError, ValueError) as exc:
        raise AppError(
            ErrorCode.UNAUTHORIZED,
            "Invalid authentication token.",
            status_code=401,
        ) from exc

    user = user_repository.get_by_id(db, user_id)
    if user is None:
        raise AppError(
            ErrorCode.UNAUTHORIZED,
            "This account no longer exists.",
            status_code=401,
        )
    if not user.is_active:
        raise AppError(
            ErrorCode.USER_INACTIVE,
            "This account has been disabled.",
            status_code=403,
        )
    return user


def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise AppError(
            ErrorCode.FORBIDDEN,
            "Administrator access is required.",
            status_code=403,
        )
    return user


def client_metadata(request: Request) -> tuple[str | None, str | None]:
    ip_address = request.client.host if request.client else None
    return ip_address, request.headers.get("user-agent")


def enforce_idempotency_header(
    request: Request, request_id: str
) -> None:
    header = request.headers.get("Idempotency-Key")
    if header and header.strip() != request_id:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Idempotency-Key must match request_id.",
            status_code=422,
        )
