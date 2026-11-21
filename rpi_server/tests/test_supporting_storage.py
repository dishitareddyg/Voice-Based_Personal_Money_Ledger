from __future__ import annotations

from datetime import datetime, timezone

import pytest
from sqlalchemy.exc import SQLAlchemyError

from app.models import (
    ApplicationEvent,
    AuditLog,
    ExchangeRateCache,
    VoiceCommand,
)
from app.models import __all__ as model_exports
from app.scripts.import_legacy_supporting_export import coerce_extended_json
from app.services import audit_service, voice_command_service


class FakeSession:
    def __init__(self) -> None:
        self.committed = False
        self.rolled_back = False
        self.closed = False

    def commit(self) -> None:
        self.committed = True

    def rollback(self) -> None:
        self.rolled_back = True

    def close(self) -> None:
        self.closed = True


def test_supporting_models_use_expected_table_names() -> None:
    assert VoiceCommand.__tablename__ == "VOICE_COMMAND"
    assert AuditLog.__tablename__ == "AUDIT_LOG"
    assert ApplicationEvent.__tablename__ == "APPLICATION_EVENT"
    assert ExchangeRateCache.__tablename__ == "EXCHANGE_RATE_CACHE"
    for name in (
        "VoiceCommand",
        "AuditLog",
        "ApplicationEvent",
        "ExchangeRateCache",
    ):
        assert name in model_exports


def test_voice_command_has_user_request_unique_key() -> None:
    names = {
        constraint.name
        for constraint in VoiceCommand.__table__.constraints
        if constraint.name
    }
    assert "uq_voice_command_user_request" in names
    assert "ck_voice_command_confidence" in names


def test_exchange_rate_cache_has_pair_unique_key() -> None:
    names = {
        constraint.name
        for constraint in ExchangeRateCache.__table__.constraints
        if constraint.name
    }
    assert "uq_exchange_rate_cache_pair" in names
    assert "ck_exchange_rate_cache_validity" in names


def test_audit_event_is_persisted_and_committed(monkeypatch) -> None:
    session = FakeSession()
    captured: dict[str, object] = {}

    monkeypatch.setattr(audit_service, "SessionLocal", lambda: session)
    monkeypatch.setattr(
        audit_service.audit_repository,
        "add_audit_log",
        lambda db, **values: captured.update(values),
    )

    audit_service.record_event(
        "transaction_created",
        user_id=7,
        request_id="req-12345678",
        payload={"transaction_id": 42},
        ip_address="127.0.0.1",
        user_agent="pytest",
    )

    assert session.committed is True
    assert session.closed is True
    assert captured["event_type"] == "transaction_created"
    assert captured["user_id"] == 7
    assert captured["payload"] == {"transaction_id": 42}


def test_audit_failure_is_best_effort(monkeypatch) -> None:
    session = FakeSession()

    def _fail(db, **values):
        raise SQLAlchemyError("audit table unavailable")

    monkeypatch.setattr(audit_service, "SessionLocal", lambda: session)
    monkeypatch.setattr(
        audit_service.audit_repository, "add_audit_log", _fail
    )

    audit_service.record_event("user_login", user_id=7)

    assert session.committed is False
    assert session.rolled_back is True
    assert session.closed is True


def test_application_event_uses_its_own_repository(monkeypatch) -> None:
    session = FakeSession()
    captured: dict[str, object] = {}

    monkeypatch.setattr(audit_service, "SessionLocal", lambda: session)
    monkeypatch.setattr(
        audit_service.audit_repository,
        "add_application_event",
        lambda db, **values: captured.update(values),
    )

    audit_service.record_application_event(
        "auth_login", user_id=9, request_id="req-abcdefgh"
    )

    assert session.committed is True
    assert captured["event_type"] == "auth_login"
    assert captured["user_id"] == 9


def test_voice_metadata_upsert_is_best_effort(monkeypatch) -> None:
    session = FakeSession()
    captured: dict[str, object] = {}

    monkeypatch.setattr(voice_command_service, "SessionLocal", lambda: session)
    monkeypatch.setattr(
        voice_command_service.voice_command_repository,
        "upsert",
        lambda db, **values: captured.update(values),
    )

    voice_command_service.record_voice_command(
        user_id=3,
        request_id="req-voice-123",
        voice_text="spent one hundred rupees",
        parser_confidence=0.91,
        transaction_id=11,
        nlp_metadata={"intent": "expense"},
    )

    assert session.committed is True
    assert session.closed is True
    assert captured["user_id"] == 3
    assert captured["request_id"] == "req-voice-123"
    assert captured["nlp_metadata"] == {"intent": "expense"}


def test_voice_metadata_failure_is_best_effort(monkeypatch) -> None:
    session = FakeSession()

    def _fail(db, **values):
        raise SQLAlchemyError("supporting table unavailable")

    monkeypatch.setattr(voice_command_service, "SessionLocal", lambda: session)
    monkeypatch.setattr(
        voice_command_service.voice_command_repository, "upsert", _fail
    )

    voice_command_service.record_voice_command(
        user_id=3,
        request_id="req-voice-456",
        voice_text="spent fifty rupees",
    )

    assert session.committed is False
    assert session.rolled_back is True
    assert session.closed is True


def test_legacy_extended_json_conversion() -> None:
    payload = {
        "rate": {"$numberDecimal": "83.12500000"},
        "created_at": {"$date": "2026-10-20T05:34:21.100Z"},
        "user_id": {"$numberLong": "2"},
        "id": {"$oid": "65f000000000000000000000"},
    }
    converted = coerce_extended_json(payload)
    assert converted["rate"].as_tuple().exponent == -8
    assert converted["created_at"] == datetime(
        2026, 10, 20, 5, 34, 21, 100000, tzinfo=None
    )
    assert converted["user_id"] == 2
    assert converted["id"] == "65f000000000000000000000"

    with pytest.raises(ValueError):
        coerce_extended_json({"$date": {"$numberLong": "not-a-number"}})


def test_timestamps_are_utc() -> None:
    value = coerce_extended_json(
        {"$date": "2026-10-20T05:34:21.100+05:30"}
    )
    assert value.tzinfo is None
    assert value == datetime(2026, 10, 20, 0, 4, 21, 100000)
    assert timezone.utc is not None
