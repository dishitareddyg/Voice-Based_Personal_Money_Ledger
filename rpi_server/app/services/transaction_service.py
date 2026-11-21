from __future__ import annotations

import logging
from datetime import date
from decimal import Decimal

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.business_rules.financial_rules import (
    assert_repayment_allowed,
    assert_sufficient_balance,
    convert_to_inr,
    direction_matches_kind,
    quantize_money,
    validate_amount,
    validate_currency,
    validate_request_fields,
)
from app.core.enums import (
    ErrorCode,
    LoanKind,
    LoanStatus,
    RepaymentDirection,
    TransactionStatus,
    TransactionType,
)
from app.core.errors import AppError
from app.core.time import today_in_timezone
from app.models.loan import Loan
from app.models.person import Person
from app.models.transaction import Transaction
from app.models.user import User
from app.repositories import (
    loan_repository,
    repayment_repository,
    transaction_repository,
    user_repository,
)
from app.schemas.transaction import (
    PaginationOut,
    TransactionCreateBase,
    TransactionCreateResponse,
    TransactionListResponse,
    TransactionOut,
)
from app.services import (
    audit_service,
    balance_service,
    currency_service,
    directory_service,
    voice_command_service,
)

logger = logging.getLogger(__name__)

_MESSAGES = {
    TransactionType.INCOME: "Income recorded successfully.",
    TransactionType.EXPENSE: "Expense recorded successfully.",
    TransactionType.SAVINGS: "Savings recorded successfully.",
    TransactionType.LENDING: "Money lent recorded successfully.",
    TransactionType.BORROWING: "Money borrowed recorded successfully.",
    TransactionType.REPAYMENT: "Repayment recorded successfully.",
}

_LOAN_TYPES = {TransactionType.LENDING, TransactionType.BORROWING}


def create_transaction(
    db: Session,
    user: User,
    payload: TransactionCreateBase,
    *,
    transaction_type: TransactionType,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> TransactionCreateResponse:
    user_id = user.id  # rollback below expires ORM attributes
    try:
        return _create_transaction(
            db,
            user,
            payload,
            transaction_type=transaction_type,
            ip_address=ip_address,
            user_agent=user_agent,
        )
    except AppError as exc:
        # Release the per-user row lock taken by SELECT ... FOR UPDATE before
        # auditing: the audit row (own session) has a FK to users and would
        # otherwise wait for this transaction.
        db.rollback()
        _record_rejection(
            user_id,
            payload,
            transaction_type=transaction_type,
            error=exc,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        raise


def _create_transaction(
    db: Session,
    user: User,
    payload: TransactionCreateBase,
    *,
    transaction_type: TransactionType,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> TransactionCreateResponse:
    existing = transaction_repository.get_by_request_id(
        db, user.id, payload.request_id
    )
    if existing is not None:
        return _replay_response(db, user, existing)

    amount = validate_amount(payload.amount)
    currency = validate_currency(payload.currency)
    validate_request_fields(
        transaction_type=transaction_type,
        repayment_direction=payload.repayment_direction,
        person_id=payload.person_id,
        person_name=payload.person_name,
        loan_id=payload.loan_id,
        interest_rate=payload.interest_rate,
        interest_type=payload.interest_type,
    )

    transaction_date = payload.transaction_date or today_in_timezone(
        user.timezone
    )

    if currency == "INR":
        exchange_rate = Decimal("1")
        amount_inr = amount
    else:
        exchange_rate = currency_service.get_rate(currency, "INR")
        amount_inr = convert_to_inr(amount, exchange_rate)

    # Serialise writes for this user. The row lock also makes the second
    # idempotency check below reliable for concurrent retries.
    user_repository.lock_by_id(db, user.id)
    existing = transaction_repository.get_by_request_id(
        db, user.id, payload.request_id
    )
    if existing is not None:
        response = _replay_response(db, user, existing)
        db.rollback()
        return response

    person = None
    if transaction_type.requires_person:
        person = directory_service.ensure_person(
            db,
            user.id,
            person_id=payload.person_id,
            person_name=payload.person_name,
        )

    category = directory_service.ensure_category(
        db,
        user.id,
        category_id=payload.category_id,
        category_name=payload.category_name,
        type_value=transaction_type.value,
    )

    loan: Loan | None = None
    if transaction_type is TransactionType.REPAYMENT:
        loan = _resolve_repayment_loan(
            db, user, payload, person=person, amount=amount_inr
        )

    assert_sufficient_balance(
        available_balance=balance_service.available_balance(db, user.id),
        amount=amount_inr,
        transaction_type=transaction_type,
    )

    transaction = transaction_repository.create(
        db,
        user_id=user.id,
        type=transaction_type.value,
        amount_inr=amount_inr,
        original_amount=amount if currency != "INR" else None,
        original_currency=currency if currency != "INR" else None,
        exchange_rate_to_inr=(
            exchange_rate if currency != "INR" else None
        ),
        transaction_date=transaction_date,
        description=payload.description,
        category_id=category.id if category is not None else None,
        person_id=person.id if person is not None else None,
        loan_id=loan.id if loan is not None else None,
        repayment_direction=(
            payload.repayment_direction.value
            if payload.repayment_direction is not None
            else None
        ),
        interest_rate=payload.interest_rate,
        interest_type=(
            payload.interest_type.value
            if payload.interest_type is not None
            else None
        ),
        status=TransactionStatus.COMPLETED.value,
        request_id=payload.request_id,
    )
    transaction.category = category
    transaction.person = person
    transaction.loan = loan

    if transaction_type in _LOAN_TYPES:
        loan = _create_loan(db, user, payload, transaction, amount_inr)
        transaction.loan = loan
        transaction.loan_id = loan.id
    elif transaction_type is TransactionType.REPAYMENT and loan is not None:
        _apply_repayment(
            db,
            user,
            payload,
            loan=loan,
            transaction=transaction,
            amount=amount_inr,
        )

    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        existing = transaction_repository.get_by_request_id(
            db, user.id, payload.request_id
        )
        if existing is None:
            logger.exception("Transaction insert failed")
            raise AppError(
                ErrorCode.DATABASE_ERROR,
                "Could not save the transaction. Please try again.",
                status_code=500,
            ) from exc
        return _replay_response(db, user, existing)

    available = balance_service.available_balance(db, user.id)

    audit_service.record_event(
        "transaction_created",
        user_id=user.id,
        request_id=payload.request_id,
        payload={
            "transaction_id": transaction.id,
            "transaction_type": transaction_type.value,
            "amount_inr": f"{amount_inr:.2f}",
            "currency": currency,
            "exchange_rate_to_inr": (
                f"{exchange_rate:.8f}" if currency != "INR" else None
            ),
            "category": category.name if category is not None else None,
            "person": person.name if person is not None else None,
            "loan_id": transaction.loan_id,
            "voice_text": payload.voice_text,
            "parser_confidence": payload.parser_confidence,
        },
        ip_address=ip_address,
        user_agent=user_agent,
    )
    audit_service.record_application_event(
        "financial_transaction_committed",
        user_id=user.id,
        request_id=payload.request_id,
        payload={
            "transaction_id": transaction.id,
            "transaction_type": transaction_type.value,
            "amount_inr": f"{amount_inr:.2f}",
            "currency": currency,
        },
        ip_address=ip_address,
        user_agent=user_agent,
    )
    if payload.voice_text:
        voice_command_service.record_voice_command(
            user_id=user.id,
            request_id=payload.request_id,
            voice_text=payload.voice_text,
            parser_confidence=payload.parser_confidence,
            transaction_id=transaction.id,
            nlp_metadata={
                "intent": transaction_type.value,
                "original_currency": currency,
                "amount": str(amount),
                "transaction_date": transaction.transaction_date.isoformat(),
                "category": (
                    category.name if category is not None else None
                ),
                "person": person.name if person is not None else None,
                "repayment_direction": (
                    payload.repayment_direction.value
                    if payload.repayment_direction is not None
                    else None
                ),
            },
        )

    return TransactionCreateResponse(
        message=_MESSAGES[transaction_type],
        transaction=TransactionOut.model_validate(transaction),
        amount_inr=amount_inr,
        exchange_rate_to_inr=(
            exchange_rate if currency != "INR" else None
        ),
        available_balance=available,
    )


def _record_rejection(
    user_id: int,
    payload: TransactionCreateBase,
    *,
    transaction_type: TransactionType,
    error: AppError,
    ip_address: str | None,
    user_agent: str | None,
) -> None:
    """Persist rejected writes without leaking implementation details."""

    audit_service.record_event(
        "transaction_rejected",
        user_id=user_id,
        request_id=payload.request_id,
        payload={
            "transaction_type": transaction_type.value,
            "amount": str(payload.amount),
            "currency": payload.currency,
            "error_code": error.code.value,
            "message": error.message,
            "details": error.details,
            "category": payload.category_name,
            "person": payload.person_name,
            "voice_text": payload.voice_text,
            "parser_confidence": payload.parser_confidence,
        },
        ip_address=ip_address,
        user_agent=user_agent,
    )


def get_transaction(
    db: Session, user: User, transaction_id: int
) -> TransactionOut:
    transaction = transaction_repository.get(db, user.id, transaction_id)
    if transaction is None:
        raise AppError(
            ErrorCode.NOT_FOUND,
            "Transaction not found.",
            status_code=404,
        )
    return TransactionOut.model_validate(transaction)


def list_transactions(
    db: Session,
    user: User,
    *,
    page: int = 1,
    page_size: int = 20,
    type_value: str | None = None,
    search: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    person_id: int | None = None,
    category_id: int | None = None,
) -> TransactionListResponse:
    if page < 1:
        raise AppError(
            ErrorCode.VALIDATION_ERROR, "Page must be 1 or greater.", status_code=422
        )
    if page_size < 1 or page_size > 100:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Page size must be between 1 and 100.",
            status_code=422,
        )
    parsed_type: TransactionType | None = None
    if type_value:
        try:
            parsed_type = TransactionType(type_value)
        except ValueError as exc:
            raise AppError(
                ErrorCode.INVALID_TRANSACTION_TYPE,
                "Unknown transaction type.",
                status_code=422,
            ) from exc

    items, total = transaction_repository.list_page(
        db,
        user.id,
        page=page,
        page_size=page_size,
        type_value=parsed_type.value if parsed_type is not None else None,
        search=search,
        date_from=date_from,
        date_to=date_to,
        person_id=person_id,
        category_id=category_id,
    )
    has_more = page * page_size < total
    return TransactionListResponse(
        items=[TransactionOut.model_validate(item) for item in items],
        page=page,
        page_size=page_size,
        total=total,
        has_more=has_more,
        pagination=PaginationOut(
            page=page,
            page_size=page_size,
            total=total,
            has_more=has_more,
        ),
    )


def _resolve_repayment_loan(
    db: Session,
    user: User,
    payload: TransactionCreateBase,
    *,
    person: Person | None,
    amount: Decimal,
) -> Loan:
    if payload.repayment_direction is None:  # guarded by validation
        raise AppError(
            ErrorCode.INVALID_REPAYMENT_DIRECTION,
            "A repayment must state whether money was received or paid.",
            status_code=422,
        )
    kind = (
        LoanKind.LENT
        if payload.repayment_direction is RepaymentDirection.RECEIVED
        else LoanKind.BORROWED
    )

    if payload.loan_id is not None:
        loan = loan_repository.get(
            db, user.id, payload.loan_id, for_update=True
        )
        if loan is None:
            raise AppError(
                ErrorCode.LOAN_NOT_FOUND,
                "Loan not found.",
                status_code=404,
            )
        if loan.kind != kind.value:
            raise AppError(
                ErrorCode.INVALID_REPAYMENT_DIRECTION,
                "The repayment direction does not match this loan.",
                status_code=422,
            )
        if person is not None and loan.person_id != person.id:
            raise AppError(
                ErrorCode.INVALID_PERSON,
                "The selected person does not match this loan.",
                status_code=422,
            )
    else:
        if person is None:
            raise AppError(
                ErrorCode.INVALID_PERSON,
                "A person is required to find the loan for this repayment.",
                status_code=422,
            )
        open_loans = loan_repository.open_for_person(
            db, user.id, person.id, kind
        )
        if not open_loans:
            raise AppError(
                ErrorCode.LOAN_NOT_FOUND,
                "No open loan was found for this person.",
                status_code=422,
            )
        if len(open_loans) > 1:
            raise AppError(
                ErrorCode.INVALID_LOAN,
                "This person has more than one open loan. "
                "Please choose the loan to repay.",
                status_code=422,
            )
        loan = loan_repository.get(
            db, user.id, open_loans[0].id, for_update=True
        )
        if loan is None:
            raise AppError(
                ErrorCode.LOAN_NOT_FOUND,
                "Loan not found.",
                status_code=404,
            )

    if loan.status == LoanStatus.CLOSED.value:
        raise AppError(
            ErrorCode.LOAN_CLOSED,
            "This loan is already closed.",
            status_code=422,
        )
    if not direction_matches_kind(payload.repayment_direction, kind):
        raise AppError(
            ErrorCode.INVALID_REPAYMENT_DIRECTION,
            "The repayment direction does not match this loan.",
            status_code=422,
        )
    assert_repayment_allowed(
        outstanding=Decimal(loan.outstanding_amount_inr), amount=amount
    )
    return loan


def _create_loan(
    db: Session,
    user: User,
    payload: TransactionCreateBase,
    transaction: Transaction,
    amount_inr: Decimal,
) -> Loan:
    assert transaction.person_id is not None
    kind = (
        LoanKind.LENT
        if transaction.type == TransactionType.LENDING.value
        else LoanKind.BORROWED
    )
    return loan_repository.create(
        db,
        user_id=user.id,
        person_id=transaction.person_id,
        kind=kind.value,
        principal_amount_inr=amount_inr,
        outstanding_amount_inr=amount_inr,
        start_date=transaction.transaction_date,
        due_date=payload.due_date,
        interest_rate=payload.interest_rate,
        interest_type=(
            payload.interest_type.value
            if payload.interest_type is not None
            else None
        ),
        status=LoanStatus.OPEN.value,
        description=payload.description,
        source_transaction_id=transaction.id,
    )


def _apply_repayment(
    db: Session,
    user: User,
    payload: TransactionCreateBase,
    *,
    loan: Loan,
    transaction: Transaction,
    amount: Decimal,
) -> None:
    remaining = quantize_money(
        Decimal(loan.outstanding_amount_inr) - amount
    )
    if remaining <= 0:
        loan.outstanding_amount_inr = Decimal("0")
        loan.status = LoanStatus.CLOSED.value
    else:
        loan.outstanding_amount_inr = remaining

    repayment_repository.create(
        db,
        user_id=user.id,
        loan_id=loan.id,
        transaction_id=transaction.id,
        person_id=loan.person_id,
        amount_inr=amount,
        direction=payload.repayment_direction.value,
        payment_date=transaction.transaction_date,
        notes=payload.description,
        status=TransactionStatus.COMPLETED.value,
    )


def _replay_response(
    db: Session, user: User, transaction: Transaction
) -> TransactionCreateResponse:
    return TransactionCreateResponse(
        message="This transaction was already saved.",
        idempotent_replay=True,
        duplicate=True,
        transaction=TransactionOut.model_validate(transaction),
        amount_inr=transaction.amount_inr,
        exchange_rate_to_inr=transaction.exchange_rate_to_inr,
        available_balance=balance_service.available_balance(db, user.id),
    )
