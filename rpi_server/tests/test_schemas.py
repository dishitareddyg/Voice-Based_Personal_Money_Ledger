from __future__ import annotations

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.core.enums import TransactionType
from app.schemas.transaction import (
    TransactionCreate,
    TypedTransactionCreate,
    VoiceCommandCreate,
)


def _base(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "request_id": "req-12345678",
        "amount": "100.00",
        "currency": "inr",
        "type": "expense",
    }
    payload.update(overrides)
    return payload


def test_expense_payload_normalises_currency_and_blanks() -> None:
    model = TransactionCreate(**_base(currency="usd", description="   "))
    assert model.currency == "USD"
    assert model.description is None
    assert model.amount == Decimal("100.00")


def test_repayment_requires_direction() -> None:
    with pytest.raises(ValidationError):
        TransactionCreate(
            **_base(
                type="repayment",
                person_name="Asha",
            )
        )


def test_repayment_requires_person() -> None:
    with pytest.raises(ValidationError):
        TransactionCreate(
            **_base(
                type="repayment",
                repayment_direction="received",
            )
        )


def test_lending_requires_person() -> None:
    with pytest.raises(ValidationError):
        TransactionCreate(**_base(type="lending"))
    model = TransactionCreate(
        **_base(type="lending", person_name="Asha")
    )
    assert model.person_name == "Asha"


def test_interest_only_for_loans() -> None:
    with pytest.raises(ValidationError):
        TransactionCreate(**_base(type="expense", interest_rate="5"))
    model = TransactionCreate(
        **_base(type="borrowing", person_name="Ravi", interest_rate="5")
    )
    assert model.interest_rate == Decimal("5")


def test_loan_id_only_for_repayment() -> None:
    with pytest.raises(ValidationError):
        TransactionCreate(**_base(type="expense", loan_id=3))


def test_typed_payload_has_no_type_field() -> None:
    payload = TypedTransactionCreate(
        **{
            "request_id": "req-abcdefgh",
            "amount": "10",
            "currency": "INR",
        }
    )
    assert not hasattr(payload, "type")


def test_voice_command_maps_intent_and_aliases() -> None:
    command = VoiceCommandCreate(
        request_id="cmd-12345678",
        intent="CREATE_EXPENSE",
        amount="2000.00",
        currency="inr",
        category_name="Groceries",
        transaction_date="2026-10-20",
        description="Weekly groceries",
        voice_text="I spent 2000 rupees on groceries",
        parser_confidence=0.97,
    )
    assert command.intent.transaction_type is TransactionType.EXPENSE
    assert command.original_currency == "INR"

    payload = command.to_transaction_payload()
    assert payload.amount == Decimal("2000.00")
    assert payload.currency == "INR"
    assert payload.category_name == "Groceries"
    assert payload.voice_text == "I spent 2000 rupees on groceries"
    assert payload.parser_confidence == 0.97


def test_voice_command_rejects_unknown_intent() -> None:
    with pytest.raises(ValidationError):
        VoiceCommandCreate(
            request_id="cmd-12345678",
            intent="DELETE_EVERYTHING",
            original_amount="10.00",
        )
