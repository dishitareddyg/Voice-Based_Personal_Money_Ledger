from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.core.errors import AppError
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    password_needs_rehash,
    verify_password,
)


def test_argon2id_hash_and_verify() -> None:
    password_hash = hash_password("CorrectHorseBatteryStaple")
    assert password_hash.startswith("$argon2id$")
    assert verify_password("CorrectHorseBatteryStaple", password_hash)
    assert not verify_password("wrong-password", password_hash)
    assert not verify_password("anything", "not-a-hash")
    assert not password_needs_rehash(password_hash)


def test_access_token_round_trip() -> None:
    token = create_access_token(user_id=42, email="a@example.com", role="user")
    payload = decode_access_token(token)
    assert payload["sub"] == "42"
    assert payload["email"] == "a@example.com"
    assert payload["role"] == "user"
    assert payload["type"] == "access"


def test_expired_token_is_rejected() -> None:
    token = create_access_token(
        user_id=1, email="a@example.com", role="user", expires_minutes=-1
    )
    with pytest.raises(AppError) as info:
        decode_access_token(token)
    assert info.value.status_code == 401


def test_tampered_token_is_rejected() -> None:
    token = create_access_token(user_id=1, email="a@example.com", role="user")
    with pytest.raises(AppError):
        decode_access_token(token + "x")


def test_utc_serialisation() -> None:
    from app.core.time import ensure_utc, to_utc_iso

    naive = datetime(2026, 1, 2, 3, 4, 5)
    aware = naive.replace(tzinfo=timezone(timedelta(hours=5, minutes=30)))
    assert to_utc_iso(naive) == "2026-01-02T03:04:05Z"
    assert to_utc_iso(aware) == "2026-01-01T21:34:05Z"
    assert ensure_utc(naive).tzinfo == timezone.utc
    assert to_utc_iso(None) is None
