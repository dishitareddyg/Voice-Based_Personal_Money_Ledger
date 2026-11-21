from __future__ import annotations

from decimal import Decimal

import httpx
import pytest

from app.core.errors import AppError
from app.services import currency_service


def test_inr_rate_is_one() -> None:
    assert currency_service.get_rate("INR", "INR") == Decimal("1")


def test_cached_rate_is_used_without_provider_call(monkeypatch) -> None:
    monkeypatch.setattr(
        currency_service, "_read_cache", lambda b, t: Decimal("83.5")
    )

    def boom(*_a):
        raise AssertionError("provider must not be called on a cache hit")

    monkeypatch.setattr(currency_service, "_fetch_rate", boom)
    assert currency_service.get_rate("usd") == Decimal("83.5")


def test_fetch_and_cache_when_missing(monkeypatch) -> None:
    written: list[tuple] = []
    monkeypatch.setattr(currency_service, "_read_cache", lambda b, t: None)
    monkeypatch.setattr(
        currency_service, "_fetch_rate", lambda b, t: Decimal("84.25")
    )
    monkeypatch.setattr(
        currency_service, "_write_cache", lambda *a: written.append(a)
    )
    assert currency_service.get_rate("EUR") == Decimal("84.25")
    assert written and written[0][:3] == ("EUR", "INR", Decimal("84.25"))


@pytest.mark.parametrize(
    "value", [Decimal("0"), Decimal("-1"), Decimal("NaN"), Decimal("1e20")]
)
def test_unusable_rates_are_rejected(value: Decimal) -> None:
    assert currency_service._normalise_rate(value) is None


def test_rate_is_quantised_with_decimal_not_float() -> None:
    rate = currency_service._normalise_rate(Decimal("0.0118929999999999"))
    assert rate == Decimal("0.011893000000")
    assert isinstance(rate, Decimal)


def _client_returning(payload=None, error: Exception | None = None):
    class FakeClient:
        def __init__(self, *args: object, **kwargs: object) -> None:
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def get(self, url: str):
            if error is not None:
                raise error
            request = httpx.Request("GET", url)
            return httpx.Response(200, json=payload, request=request)

    return FakeClient


def test_fetch_failure_is_a_clear_error(monkeypatch) -> None:
    monkeypatch.setattr(
        currency_service.httpx,
        "Client",
        _client_returning(error=httpx.ConnectError("no network")),
    )
    monkeypatch.setattr(currency_service, "_read_cache", lambda b, t: None)
    with pytest.raises(AppError) as info:
        currency_service.get_rate("USD")
    assert info.value.code.value == "EXCHANGE_RATE_UNAVAILABLE"
    assert info.value.status_code == 503


def test_missing_rate_in_provider_payload(monkeypatch) -> None:
    monkeypatch.setattr(
        currency_service.httpx,
        "Client",
        _client_returning({"rates": {"EUR": 1}}),
    )
    monkeypatch.setattr(currency_service, "_read_cache", lambda b, t: None)
    with pytest.raises(AppError):
        currency_service.get_rate("USD")
