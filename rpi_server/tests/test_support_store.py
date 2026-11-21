"""MySQL-backed tests for the four support tables (need a live MySQL 8)."""

from __future__ import annotations

import uuid
from datetime import timedelta
from decimal import Decimal

import httpx
import pytest
from sqlalchemy import select, text

from app.core.errors import AppError
from app.core.time import utc_now_naive
from app.database.mysql.session import SessionLocal
from app.models.application_event import ApplicationEvent
from app.models.audit_log import AuditLog
from app.models.exchange_rate_cache import ExchangeRateCache
from app.models.voice_command import VoiceCommand
from app.services import (
    admin_service,
    audit_service,
    currency_service,
    voice_command_service,
)

pytestmark = pytest.mark.usefixtures("mysql_db")


def _rid() -> str:
    return uuid.uuid4().hex


# --- audit ------------------------------------------------------------------


def test_audit_event_is_persisted_with_json_payload(make_user) -> None:
    user_id, rid = make_user(), _rid()
    audit_service.record_event(
        "transaction_created",
        user_id=user_id,
        request_id=rid,
        payload={"amount_inr": "100.00", "nested": {"a": [1, 2]}, "x": None},
        ip_address="10.0.0.5",
        user_agent="pytest",
    )
    with SessionLocal() as db:
        row = db.scalar(select(AuditLog).where(AuditLog.request_id == rid))
    assert row is not None
    assert row.user_id == user_id
    assert row.event_type == "transaction_created"
    assert row.payload == {
        "amount_inr": "100.00",
        "nested": {"a": [1, 2]},
        "x": None,
    }
    assert row.ip_address == "10.0.0.5"
    assert row.created_at <= utc_now_naive()


def test_application_event_is_separate_from_audit_log(make_user) -> None:
    user_id, rid = make_user(), _rid()
    audit_service.record_application_event(
        "auth_login", user_id=user_id, request_id=rid
    )
    with SessionLocal() as db:
        events = db.scalars(
            select(ApplicationEvent).where(ApplicationEvent.request_id == rid)
        ).all()
        audits = db.scalars(
            select(AuditLog).where(AuditLog.request_id == rid)
        ).all()
    assert len(events) == 1 and events[0].payload is None
    assert audits == []


def test_audit_payload_with_decimal_and_long_fields_is_stored(
    make_user,
) -> None:
    rid = _rid()
    audit_service.record_event(
        "x",
        user_id=make_user(),
        request_id=rid,
        payload={"amount": Decimal("12.50")},
        user_agent="u" * 2000,
    )
    with SessionLocal() as db:
        row = db.scalar(select(AuditLog).where(AuditLog.request_id == rid))
    assert row.payload == {"amount": "12.50"}
    assert len(row.user_agent) == 512


def test_audit_is_best_effort_and_never_raises(monkeypatch, caplog) -> None:
    def broken():
        raise RuntimeError("database down")

    monkeypatch.setattr(audit_service, "SessionLocal", broken)
    audit_service.record_event("boom")  # must not raise
    audit_service.record_application_event("boom")
    assert "was not persisted" in caplog.text


def test_audit_with_unknown_user_fails_softly(caplog) -> None:
    rid = _rid()
    audit_service.record_event("x", user_id=2_000_000_000, request_id=rid)
    with SessionLocal() as db:
        assert (
            db.scalar(select(AuditLog).where(AuditLog.request_id == rid))
            is None
        )
    assert "was not persisted" in caplog.text


# --- voice commands -----------------------------------------------------------


def _voice(user_id: int, rid: str, text_: str = "spent fifty", **kw) -> None:
    voice_command_service.record_voice_command(
        user_id=user_id,
        request_id=rid,
        voice_text=text_,
        parser_confidence=0.97,
        nlp_metadata={"intent": "expense"},
        **kw,
    )


def test_voice_command_idempotent_first_write_wins(make_user) -> None:
    user_id, rid = make_user(), _rid()
    _voice(user_id, rid, "first")
    _voice(user_id, rid, "retry with different text")
    _voice(user_id, rid, "again")
    with SessionLocal() as db:
        rows = db.scalars(
            select(VoiceCommand).where(
                VoiceCommand.user_id == user_id,
                VoiceCommand.request_id == rid,
            )
        ).all()
    assert len(rows) == 1
    assert rows[0].voice_text == "first"
    assert rows[0].parser_confidence == 0.97
    assert rows[0].nlp == {"intent": "expense"}
    assert rows[0].source == "android_speech_recognizer"


def test_voice_command_user_isolation(make_user) -> None:
    alice, bob, rid = make_user(), make_user(), _rid()
    _voice(alice, rid, "alice text")
    _voice(bob, rid, "bob text")  # same request_id, different user: allowed
    with SessionLocal() as db:
        rows = {
            r.user_id: r.voice_text
            for r in db.scalars(
                select(VoiceCommand).where(VoiceCommand.request_id == rid)
            )
        }
        assert rows == {alice: "alice text", bob: "bob text"}
        alice_rows = db.scalars(
            select(VoiceCommand).where(VoiceCommand.user_id == alice)
        ).all()
    assert all(r.user_id == alice for r in alice_rows)


def test_voice_command_confidence_and_fk_enforced(make_user) -> None:
    from sqlalchemy.exc import DBAPIError, IntegrityError

    with pytest.raises(DBAPIError):  # MySQL reports CHECK as error 3819
        with SessionLocal() as db:
            db.add(
                VoiceCommand(
                    user_id=make_user(),
                    request_id=_rid(),
                    voice_text="x",
                    parser_confidence=1.5,
                    nlp={},
                )
            )
            db.commit()
    with pytest.raises(IntegrityError):
        with SessionLocal() as db:
            db.add(
                VoiceCommand(
                    user_id=2_000_000_000,
                    request_id=_rid(),
                    voice_text="x",
                    nlp={},
                )
            )
            db.commit()


# --- exchange-rate cache --------------------------------------------------------


def _clear_pair(base: str, target: str = "INR") -> None:
    with SessionLocal() as db:
        db.execute(
            text(
                "DELETE FROM EXCHANGE_RATE_CACHE "
                "WHERE base_currency=:b AND target_currency=:t"
            ),
            {"b": base, "t": target},
        )
        db.commit()


def _no_provider(monkeypatch) -> None:
    def boom(*_a):
        raise AssertionError("provider must not be called")

    monkeypatch.setattr(currency_service, "_fetch_rate", boom)


def test_rate_is_cached_then_served_from_mysql(monkeypatch) -> None:
    _clear_pair("AUD")
    calls: list[int] = []

    def fetch(b, t):
        calls.append(1)
        return Decimal("54.123456789")

    monkeypatch.setattr(currency_service, "_fetch_rate", fetch)
    assert currency_service.get_rate("AUD") == Decimal("54.123456789")
    assert currency_service.get_rate("aud") == Decimal("54.123456789")
    assert calls == [1]  # second call came from the cache
    with SessionLocal() as db:
        row = db.scalar(
            select(ExchangeRateCache).where(
                ExchangeRateCache.base_currency == "AUD"
            )
        )
    assert isinstance(row.rate, Decimal)
    assert row.valid_until > row.retrieved_at


def test_expired_rate_is_refetched_and_row_is_upserted(monkeypatch) -> None:
    _clear_pair("CAD")
    past = utc_now_naive() - timedelta(hours=2)
    with SessionLocal() as db:
        db.add(
            ExchangeRateCache(
                base_currency="CAD",
                target_currency="INR",
                rate=Decimal("60"),
                provider="old",
                retrieved_at=past,
                valid_until=past + timedelta(minutes=60),
            )
        )
        db.commit()
    assert currency_service._read_cache("CAD", "INR") is None  # expired
    monkeypatch.setattr(
        currency_service, "_fetch_rate", lambda b, t: Decimal("61.5")
    )
    assert currency_service.get_rate("CAD") == Decimal("61.5")
    with SessionLocal() as db:
        rows = db.scalars(
            select(ExchangeRateCache).where(
                ExchangeRateCache.base_currency == "CAD"
            )
        ).all()
    assert len(rows) == 1  # refreshed in place, unique per pair
    assert rows[0].rate == Decimal("61.5")
    assert rows[0].provider != "old"
    assert currency_service._read_cache("CAD", "INR") == Decimal("61.5")


def test_cache_boundary_valid_until_must_be_in_future() -> None:
    _clear_pair("NZD")
    now = utc_now_naive()
    with SessionLocal() as db:
        db.add(
            ExchangeRateCache(
                base_currency="NZD",
                target_currency="INR",
                rate=Decimal("50"),
                provider="p",
                retrieved_at=now - timedelta(minutes=5),
                valid_until=now - timedelta(microseconds=1),
            )
        )
        db.commit()
    assert currency_service._read_cache("NZD", "INR") is None


def test_external_fallback_when_cache_unavailable(monkeypatch) -> None:
    """Cache errors must not break conversions: the provider is canonical."""

    def broken():
        raise currency_service.SQLAlchemyError("cache down")

    monkeypatch.setattr(currency_service, "SessionLocal", broken)
    monkeypatch.setattr(
        currency_service, "_fetch_rate", lambda b, t: Decimal("90.1")
    )
    assert currency_service.get_rate("CHF") == Decimal("90.1")


def test_external_provider_failure_after_cache_miss(monkeypatch) -> None:
    _clear_pair("SGD")

    class Down:
        def __init__(self, *a, **k):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return None

        def get(self, url):
            raise httpx.ConnectError("offline")

    monkeypatch.setattr(currency_service.httpx, "Client", Down)
    with pytest.raises(AppError) as info:
        currency_service.get_rate("SGD")
    assert info.value.code.value == "EXCHANGE_RATE_UNAVAILABLE"


def test_provider_payload_end_to_end_with_decimal(monkeypatch) -> None:
    _clear_pair("GBP")

    class Ok:
        def __init__(self, *a, **k):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return None

        def get(self, url):
            assert url.endswith("/GBP")
            return httpx.Response(
                200,
                json={"rates": {"INR": 105.123456}},
                request=httpx.Request("GET", url),
            )

    monkeypatch.setattr(currency_service.httpx, "Client", Ok)
    assert currency_service.get_rate("GBP") == Decimal("105.123456")
    _no_provider(monkeypatch)
    assert currency_service.get_rate("GBP") == Decimal("105.123456")


# --- admin ------------------------------------------------------------------------


def test_admin_stats_and_prune(make_user) -> None:
    audit_service.record_event("stats_probe", user_id=make_user())
    _voice(make_user(), _rid())
    past = utc_now_naive() - timedelta(days=1)
    _clear_pair("JPY")
    with SessionLocal() as db:
        db.add(
            ExchangeRateCache(
                base_currency="JPY",
                target_currency="INR",
                rate=Decimal("0.55"),
                provider="p",
                retrieved_at=past - timedelta(hours=1),
                valid_until=past,
            )
        )
        db.commit()

    with SessionLocal() as db:
        stats = admin_service._database_stats(db)
    assert stats["mysql_version"].startswith("8")
    supporting = stats["supporting_tables"]
    assert set(supporting) == {
        "voice_commands",
        "audit_logs",
        "exchange_rates",
        "application_events",
    }
    assert supporting["audit_logs"] >= 1 and supporting["voice_commands"] >= 1
    assert supporting["exchange_rates"] >= 1
    tables = {t["table"] for t in stats["tables"]}
    assert {"VOICE_COMMAND", "AUDIT_LOG", "APPLICATION_EVENT",
            "EXCHANGE_RATE_CACHE"} <= tables

    with SessionLocal() as db:
        result = admin_service._prune_rate_cache(db)
    assert result["deleted"] >= 1
    assert currency_service._read_cache("JPY", "INR") is None
    with SessionLocal() as db:
        assert db.scalar(
            select(ExchangeRateCache).where(
                ExchangeRateCache.base_currency == "JPY"
            )
        ) is None


def test_admin_optimize_includes_support_tables(mysql_db) -> None:
    with SessionLocal() as db:
        details = admin_service._optimize_indexes(db)
    names = {row["table"].split(".")[-1] for row in details["tables"]}
    assert {"AUDIT_LOG", "VOICE_COMMAND"} <= names


# --- schema / migration parity ------------------------------------------------------


def test_models_match_migrated_schema(mysql_db) -> None:
    from alembic.autogenerate import compare_metadata
    from alembic.migration import MigrationContext

    import app.models  # noqa: F401
    from app.database.mysql.base import Base

    with mysql_db.connect() as conn:
        context = MigrationContext.configure(
            conn, opts={"compare_type": True}
        )
        assert compare_metadata(context, Base.metadata) == []
