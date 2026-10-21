"""Deterministic financial validation shared by the API and the DB layer."""

from __future__ import annotations

import re
from decimal import ROUND_HALF_UP, Decimal

from app.core.enums import (
    ErrorCode,
    LoanKind,
    RepaymentDirection,
    TransactionType,
)
from app.core.errors import AppError

MONEY_QUANTUM = Decimal("0.01")
MAX_AMOUNT = Decimal("9999999999999.99")
CURRENCY_PATTERN = re.compile(r"^[A-Z]{3}$")


def quantize_money(value: Decimal) -> Decimal:
    return value.quantize(MONEY_QUANTUM, rounding=ROUND_HALF_UP)


def validate_amount(amount: Decimal) -> Decimal:
    if amount is None or amount <= 0:
        raise AppError(
            ErrorCode.INVALID_AMOUNT,
            "Amount must be greater than zero.",
            status_code=422,
        )
    if amount > MAX_AMOUNT:
        raise AppError(
            ErrorCode.INVALID_AMOUNT,
            "Amount exceeds the maximum supported value.",
            status_code=422,
        )
    return quantize_money(amount)


def validate_currency(currency: str | None) -> str:
    normalized = (currency or "INR").strip().upper()
    if not CURRENCY_PATTERN.match(normalized):
        raise AppError(
            ErrorCode.INVALID_CURRENCY,
            "Currency must be a three-letter ISO code.",
            status_code=422,
        )
    return normalized


def validate_interest_rate(rate: Decimal | None) -> None:
    if rate is None:
        return
    if rate < 0 or rate > 100:
        raise AppError(
            ErrorCode.INVALID_INTEREST_RATE,
            "Interest rate must be between 0 and 100 percent.",
            status_code=422,
        )


def validate_request_fields(
    *,
    transaction_type: TransactionType,
    repayment_direction: RepaymentDirection | None,
    person_id: int | None,
    person_name: str | None,
    loan_id: int | None,
    interest_rate: Decimal | None,
    interest_type: object | None,
) -> None:
    if transaction_type.requires_person and not (
        person_id is not None or (person_name and person_name.strip())
    ):
        raise AppError(
            ErrorCode.INVALID_PERSON,
            "This transaction needs a person.",
            status_code=422,
        )

    if transaction_type is TransactionType.REPAYMENT:
        if repayment_direction is None:
            raise AppError(
                ErrorCode.INVALID_REPAYMENT_DIRECTION,
                "A repayment must state whether money was received or paid.",
                status_code=422,
            )
    else:
        if repayment_direction is not None:
            raise AppError(
                ErrorCode.INVALID_REPAYMENT_DIRECTION,
                "Repayment direction is only valid for repayments.",
                status_code=422,
            )
        if loan_id is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "A loan can only be linked to a repayment.",
                status_code=422,
            )

    if transaction_type not in (
        TransactionType.LENDING,
        TransactionType.BORROWING,
    ) and (interest_rate is not None or interest_type is not None):
        raise AppError(
            ErrorCode.INVALID_INTEREST_RATE,
            "Interest is only valid for lending or borrowing.",
            status_code=422,
        )

    validate_interest_rate(interest_rate)


def assert_sufficient_balance(
    *, available_balance: Decimal, amount: Decimal, transaction_type: TransactionType
) -> None:
    if transaction_type.requires_balance and amount > available_balance:
        raise AppError(
            ErrorCode.INSUFFICIENT_BALANCE,
            "Insufficient available balance for this transaction.",
            status_code=422,
            details={
                "available_balance": f"{quantize_money(available_balance):.2f}",
                "requested_amount": f"{quantize_money(amount):.2f}",
            },
        )


def assert_repayment_allowed(
    *, outstanding: Decimal, amount: Decimal
) -> None:
    if amount > outstanding:
        raise AppError(
            ErrorCode.REPAYMENT_EXCEEDS_OUTSTANDING,
            "Repayment exceeds the outstanding loan amount.",
            status_code=422,
            details={
                "outstanding_amount": f"{quantize_money(outstanding):.2f}",
                "requested_amount": f"{quantize_money(amount):.2f}",
            },
        )


def convert_to_inr(amount: Decimal, rate: Decimal) -> Decimal:
    return quantize_money(amount * rate)


def direction_matches_kind(
    direction: RepaymentDirection, kind: LoanKind
) -> bool:
    if direction is RepaymentDirection.RECEIVED:
        return kind is LoanKind.LENT
    return kind is LoanKind.BORROWED
