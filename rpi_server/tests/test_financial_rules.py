from __future__ import annotations

from decimal import Decimal

import pytest

from app.business_rules.financial_rules import (
    assert_repayment_allowed,
    assert_sufficient_balance,
    convert_to_inr,
    direction_matches_kind,
    quantize_money,
    validate_amount,
    validate_currency,
    validate_interest_rate,
    validate_request_fields,
)
from app.core.enums import LoanKind, RepaymentDirection, TransactionType
from app.core.errors import AppError


def test_amount_validation_and_rounding() -> None:
    assert validate_amount(Decimal("10.005")) == Decimal("10.01")
    assert quantize_money(Decimal("0.005")) == Decimal("0.01")
    for value in (Decimal("0"), Decimal("-5")):
        with pytest.raises(AppError) as info:
            validate_amount(value)
        assert info.value.code.value == "INVALID_AMOUNT"


def test_currency_validation() -> None:
    assert validate_currency("usd") == "USD"
    assert validate_currency(None) == "INR"
    with pytest.raises(AppError):
        validate_currency("US")
    with pytest.raises(AppError):
        validate_currency("DOLLAR")


def test_interest_validation() -> None:
    validate_interest_rate(None)
    validate_interest_rate(Decimal("12.5"))
    with pytest.raises(AppError):
        validate_interest_rate(Decimal("-1"))
    with pytest.raises(AppError):
        validate_interest_rate(Decimal("101"))


def test_request_fields_for_repayment() -> None:
    validate_request_fields(
        transaction_type=TransactionType.REPAYMENT,
        repayment_direction=RepaymentDirection.RECEIVED,
        person_id=1,
        person_name=None,
        loan_id=None,
        interest_rate=None,
        interest_type=None,
    )
    with pytest.raises(AppError) as info:
        validate_request_fields(
            transaction_type=TransactionType.REPAYMENT,
            repayment_direction=None,
            person_id=1,
            person_name=None,
            loan_id=None,
            interest_rate=None,
            interest_type=None,
        )
    assert info.value.code.value == "INVALID_REPAYMENT_DIRECTION"


def test_request_fields_require_person() -> None:
    with pytest.raises(AppError) as info:
        validate_request_fields(
            transaction_type=TransactionType.LENDING,
            repayment_direction=None,
            person_id=None,
            person_name="  ",
            loan_id=None,
            interest_rate=None,
            interest_type=None,
        )
    assert info.value.code.value == "INVALID_PERSON"


def test_interest_only_for_loans() -> None:
    with pytest.raises(AppError) as info:
        validate_request_fields(
            transaction_type=TransactionType.EXPENSE,
            repayment_direction=None,
            person_id=None,
            person_name=None,
            loan_id=None,
            interest_rate=Decimal("5"),
            interest_type=None,
        )
    assert info.value.code.value == "INVALID_INTEREST_RATE"


def test_balance_guard() -> None:
    assert_sufficient_balance(
        available_balance=Decimal("100"),
        amount=Decimal("100"),
        transaction_type=TransactionType.EXPENSE,
    )
    with pytest.raises(AppError) as info:
        assert_sufficient_balance(
            available_balance=Decimal("99.99"),
            amount=Decimal("100"),
            transaction_type=TransactionType.EXPENSE,
        )
    assert info.value.code.value == "INSUFFICIENT_BALANCE"
    assert_sufficient_balance(
        available_balance=Decimal("0"),
        amount=Decimal("100"),
        transaction_type=TransactionType.INCOME,
    )


def test_repayment_guard() -> None:
    assert_repayment_allowed(
        outstanding=Decimal("100"), amount=Decimal("100")
    )
    with pytest.raises(AppError) as info:
        assert_repayment_allowed(
            outstanding=Decimal("100"), amount=Decimal("100.01")
        )
    assert info.value.code.value == "REPAYMENT_EXCEEDS_OUTSTANDING"


def test_conversion_and_direction() -> None:
    assert convert_to_inr(
        Decimal("10.00"), Decimal("83.12345678")
    ) == Decimal("831.23")
    assert direction_matches_kind(
        RepaymentDirection.RECEIVED, LoanKind.LENT
    )
    assert direction_matches_kind(
        RepaymentDirection.PAID, LoanKind.BORROWED
    )
    assert not direction_matches_kind(
        RepaymentDirection.RECEIVED, LoanKind.BORROWED
    )
