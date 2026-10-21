"""Argon2id password hashing and JWT access tokens."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher, Type
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from app.core.config import get_settings
from app.core.enums import ErrorCode
from app.core.errors import AppError

# OWASP-recommended Argon2id parameters, comfortable on a Raspberry Pi 4B.
_hasher = PasswordHasher(
    time_cost=2,
    memory_cost=19456,
    parallelism=1,
    hash_len=32,
    salt_len=16,
    type=Type.ID,
)


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def password_needs_rehash(password_hash: str) -> bool:
    try:
        return _hasher.check_needs_rehash(password_hash)
    except InvalidHashError:
        return True


def create_access_token(
    *,
    user_id: int,
    email: str,
    role: str,
    expires_minutes: int | None = None,
) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expire = now + timedelta(
        minutes=expires_minutes or settings.access_token_expire_minutes
    )
    payload = {
        "sub": str(user_id),
        "email": email,
        "role": role,
        "type": "access",
        "iss": settings.jwt_issuer,
        "iat": now,
        "exp": expire,
    }
    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_access_token(token: str) -> dict[str, object]:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            issuer=settings.jwt_issuer,
            options={"require": ["exp", "sub", "iss"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise AppError(
            ErrorCode.UNAUTHORIZED,
            "Your session has expired. Please sign in again.",
            status_code=401,
        ) from exc
    except jwt.PyJWTError as exc:
        raise AppError(
            ErrorCode.UNAUTHORIZED,
            "Invalid authentication token.",
            status_code=401,
        ) from exc

    if payload.get("type") != "access":
        raise AppError(
            ErrorCode.UNAUTHORIZED,
            "Invalid authentication token type.",
            status_code=401,
        )
    return payload
