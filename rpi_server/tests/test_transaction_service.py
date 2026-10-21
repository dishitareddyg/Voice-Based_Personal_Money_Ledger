from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.core.enums import TransactionType
from app.core.errors import AppError
from app.schemas.transaction import TypedTransactionCreate
from app.services import audit_service, transaction_service


def test_rejected_write_is_audited_and_reraised(monkeypatch) -> None:
    payload = TypedTransactionCreate(
        request_id="reject-12345678",
        amount="-1.00",
        currency="INR",
        description="Invalid amount",
        voice_text="I spent minus one rupee",
        parser_confidence=0.8,
    )
    user = SimpleNamespace(id=7)
    audit_calls: list[tuple[str, dict]] = []

    monkeypatch.setattr(
        transaction_service.transaction_repository,
        "get_by_request_id",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(
        audit_service,
        "record_event",
        lambda event_type, **kwargs: audit_calls.append((event_type, kwargs)),
    )

    with pytest.raises(AppError) as raised:
        transaction_service.create_transaction(
            None,
            user,
            payload,
            transaction_type=TransactionType.EXPENSE,
            ip_address="127.0.0.1",
            user_agent="pytest",
        )

    assert raised.value.code.value == "INVALID_AMOUNT"
    assert len(audit_calls) == 1
    event_type, kwargs = audit_calls[0]
    assert event_type == "transaction_rejected"
    assert kwargs["user_id"] == 7
    assert kwargs["request_id"] == "reject-12345678"
    assert kwargs["payload"]["error_code"] == "INVALID_AMOUNT"
    assert kwargs["payload"]["transaction_type"] == "expense"
    assert kwargs["payload"]["voice_text"] == "I spent minus one rupee"
