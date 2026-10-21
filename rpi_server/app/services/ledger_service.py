from __future__ import annotations

from sqlalchemy.orm import Session

from app.core.enums import ErrorCode, LoanKind
from app.core.errors import AppError
from app.models.user import User
from app.repositories import loan_repository, repayment_repository
from app.schemas.transaction import (
    LoanListResponse,
    LoanOut,
    RepaymentListResponse,
    RepaymentOut,
)


def list_loans(
    db: Session,
    user: User,
    *,
    kind: str | None = None,
    status: str | None = None,
    person_id: int | None = None,
    limit: int = 100,
) -> LoanListResponse:
    parsed_kind: LoanKind | None = None
    if kind:
        try:
            parsed_kind = LoanKind(kind)
        except ValueError as exc:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Loan kind must be 'lent' or 'borrowed'.",
                status_code=422,
            ) from exc
    loans = loan_repository.list_loans(
        db,
        user.id,
        kind=parsed_kind,
        status=status,
        person_id=person_id,
        limit=min(max(limit, 1), 500),
    )
    return LoanListResponse(
        loans=[LoanOut.model_validate(loan) for loan in loans]
    )


def list_repayments(
    db: Session,
    user: User,
    *,
    loan_id: int | None = None,
    limit: int = 100,
) -> RepaymentListResponse:
    repayments = repayment_repository.list_all(
        db,
        user.id,
        loan_id=loan_id,
        limit=min(max(limit, 1), 500),
    )
    return RepaymentListResponse(
        repayments=[
            RepaymentOut.model_validate(repayment)
            for repayment in repayments
        ]
    )
