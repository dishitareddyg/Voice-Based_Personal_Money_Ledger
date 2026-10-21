from __future__ import annotations

from decimal import Decimal

from bson.decimal128 import Decimal128

from app.services import currency_service


class FakeCollection:
    def __init__(self, document: dict | None = None) -> None:
        self.document = document
        self.upserts: list[dict] = []

    def find_one(self, *args: object, **kwargs: object):
        return self.document

    def update_one(self, key: dict, update: dict, upsert: bool = False):
        self.upserts.append({"key": key, "update": update, "upsert": upsert})


def test_inr_rate_is_one() -> None:
    assert currency_service.get_rate("INR", "INR") == Decimal("1")


def test_cached_rate_is_used(monkeypatch) -> None:
    collection = FakeCollection(
        {"rate": Decimal128(Decimal("83.50000000"))}
    )
    monkeypatch.setattr(currency_service, "_collection", lambda: collection)
    assert currency_service.get_rate("usd") == Decimal("83.50000000")
    assert collection.upserts == []


def test_fetch_and_cache_when_missing(monkeypatch) -> None:
    collection = FakeCollection(None)
    monkeypatch.setattr(currency_service, "_collection", lambda: collection)
    monkeypatch.setattr(
        currency_service, "_fetch_rate", lambda base, target: Decimal("84.25")
    )
    rate = currency_service.get_rate("EUR")
    assert rate == Decimal("84.25")
    assert collection.upserts
    stored = collection.upserts[0]["update"]["$set"]
    assert stored["base_currency"] == "EUR"
    assert stored["target_currency"] == "INR"
    assert stored["rate"] == Decimal128(Decimal("84.25"))
    assert stored["valid_until"] > stored["retrieved_at"]


def test_fetch_failure_is_a_clear_error(monkeypatch) -> None:
    import httpx

    class BrokenClient:
        def __init__(self, *args: object, **kwargs: object) -> None:
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def get(self, url: str):
            raise httpx.ConnectError("no network")

    monkeypatch.setattr(currency_service.httpx, "Client", BrokenClient)
    collection = FakeCollection(None)
    monkeypatch.setattr(currency_service, "_collection", lambda: collection)
    try:
        currency_service.get_rate("USD")
    except Exception as exc:  # AppError
        assert getattr(exc, "code").value == "EXCHANGE_RATE_UNAVAILABLE"
        assert getattr(exc, "status_code") == 503
    else:  # pragma: no cover
        raise AssertionError("expected an exchange-rate error")
