from __future__ import annotations

from datetime import date
from decimal import Decimal

from pydantic import AliasChoices, Field, field_validator, model_validator

from app.business_rules.financial_rules import validate_request_fields
from app.core.enums import (
    CommandIntent,
    InterestType,
    LoanKind,
    RepaymentDirection,
    TransactionType,
)
from app.core.errors import AppError
from app.schemas.common import AmountInput, APIModel, RateInput, UtcDateTime


class TransactionCreateBase(APIModel):
    """Common payload. The transaction type comes from the endpoint or body."""

    request_id: str = Field(min_length=8, max_length=64)
    amount: AmountInput
    currency: str = Field(default="INR", min_length=3, max_length=3)
    transaction_date: date | None = None
    description: str | None = Field(default=None, max_length=255)
    category_id: int | None = Field(default=None, gt=0)
    category_name: str | None = Field(default=None, max_length=80)
    person_id: int | None = Field(default=None, gt=0)
    person_name: str | None = Field(default=None, max_length=120)
    interest_rate: RateInput | None = None
    interest_type: InterestType | None = None
    repayment_direction: RepaymentDirection | None = None
    loan_id: int | None = Field(default=None, gt=0)
    due_date: date | None = None
    voice_text: str | None = Field(default=None, max_length=2000)
    parser_confidence: float | None = Field(default=None, ge=0, le=1)

    @field_validator(
        "description",
        "category_name",
        "person_name",
        "voice_text",
        mode="before",
    )
    @classmethod
    def _blank_to_none(cls, value: object) -> object:
        if isinstance(value, str):
            stripped = value.strip()
            return stripped or None
        return value

    @field_validator("currency")
    @classmethod
    def _normalize_currency(cls, value: str) -> str:
        return value.strip().upper()


class TransactionCreate(TransactionCreateBase):
    type: TransactionType

    @model_validator(mode="after")
    def _check_business_fields(self) -> "TransactionCreate":
        try:
            validate_request_fields(
                transaction_type=self.type,
                repayment_direction=self.repayment_direction,
                person_id=self.person_id,
                person_name=self.person_name,
                loan_id=self.loan_id,
                interest_rate=self.interest_rate,
                interest_type=self.interest_type,
            )
        except AppError as exc:
            raise ValueError(exc.message) from exc
        return self


class TypedTransactionCreate(TransactionCreateBase):
    """Payload for /expenses, /lending, ... where the type is implicit."""


class VoiceCommandCreate(APIModel):
    """Canonical structured command sent by the Flutter voice flow.

    The mobile app never sends SQL. It sends the confirmed intent plus the
    extracted fields; the server maps the intent to the authoritative ledger
    operation and applies the same financial rules as the typed endpoints.
    """

    request_id: str = Field(min_length=8, max_length=64)
    intent: CommandIntent
    original_amount: AmountInput = Field(
        validation_alias=AliasChoices("original_amount", "amount")
    )
    original_currency: str = Field(
        default="INR",
        min_length=3,
        max_length=3,
        validation_alias=AliasChoices("original_currency", "currency"),
    )
    transaction_date: date | None = None
    description: str | None = Field(default=None, max_length=255)
    category: str | None = Field(
        default=None,
        max_length=80,
        validation_alias=AliasChoices("category", "category_name"),
    )
    category_id: int | None = Field(default=None, gt=0)
    person: str | None = Field(
        default=None,
        max_length=120,
        validation_alias=AliasChoices("person", "person_name"),
    )
    person_id: int | None = Field(default=None, gt=0)
    interest_rate: RateInput | None = None
    interest_type: InterestType | None = None
    repayment_direction: RepaymentDirection | None = None
    loan_id: int | None = Field(default=None, gt=0)
    due_date: date | None = None
    voice_text: str | None = Field(default=None, max_length=2000)
    parser_confidence: float | None = Field(default=None, ge=0, le=1)

    @field_validator(
        "description",
        "category",
        "person",
        "voice_text",
        mode="before",
    )
    @classmethod
    def _blank_to_none(cls, value: object) -> object:
        if isinstance(value, str):
            stripped = value.strip()
            return stripped or None
        return value

    @field_validator("original_currency")
    @classmethod
    def _normalize_currency(cls, value: str) -> str:
        return value.strip().upper()

    def to_transaction_payload(self) -> TransactionCreateBase:
        return TransactionCreateBase(
            request_id=self.request_id,
            amount=self.original_amount,
            currency=self.original_currency,
            transaction_date=self.transaction_date,
            description=self.description,
            category_id=self.category_id,
            category_name=self.category,
            person_id=self.person_id,
            person_name=self.person,
            interest_rate=self.interest_rate,
            interest_type=self.interest_type,
            repayment_direction=self.repayment_direction,
            loan_id=self.loan_id,
            due_date=self.due_date,
            voice_text=self.voice_text,
            parser_confidence=self.parser_confidence,
        )


class TransactionOut(APIModel):
    id: int
    user_id: int
    type: TransactionType
    amount_inr: Decimal
    currency: str = "INR"
    original_amount: Decimal | None = None
    original_currency: str | None = None
    exchange_rate_to_inr: Decimal | None = None
    transaction_date: date
    description: str | None = None
    category_id: int | None = None
    category_name: str | None = None
    person_id: int | None = None
    person_name: str | None = None
    interest_rate: Decimal | None = None
    interest_type: InterestType | None = None
    loan_id: int | None = None
    repayment_direction: RepaymentDirection | None = None
    status: str = "completed"
    reference: str | None = None
    request_id: str
    created_at: UtcDateTime
    updated_at: UtcDateTime


class TransactionCreateResponse(APIModel):
    success: bool = True
    message: str
    idempotent_replay: bool = False
    duplicate: bool = False
    transaction: TransactionOut
    amount_inr: Decimal
    exchange_rate_to_inr: Decimal | None = None
    available_balance: Decimal


class TransactionResponse(APIModel):
    success: bool = True
    transaction: TransactionOut


class PaginationOut(APIModel):
    page: int
    page_size: int
    total: int
    has_more: bool


class TransactionListResponse(APIModel):
    success: bool = True
    items: list[TransactionOut]
    page: int
    page_size: int
    total: int
    has_more: bool
    pagination: PaginationOut


class LoanOut(APIModel):
    id: int
    kind: LoanKind
    person_id: int
    person_name: str | None = None
    principal_amount_inr: Decimal
    outstanding_amount_inr: Decimal
    start_date: date
    interest_rate: Decimal | None = None
    interest_type: InterestType | None = None
    due_date: date | None = None
    status: str
    description: str | None = None
    created_at: UtcDateTime | None = None


class LoanListResponse(APIModel):
    success: bool = True
    loans: list[LoanOut]


class RepaymentOut(APIModel):
    id: int
    loan_id: int
    person_id: int
    person_name: str | None = None
    amount_inr: Decimal
    payment_date: date
    direction: RepaymentDirection
    notes: str | None = None
    status: str = "completed"
    created_at: UtcDateTime | None = None


class RepaymentListResponse(APIModel):
    success: bool = True
    repayments: list[RepaymentOut]
