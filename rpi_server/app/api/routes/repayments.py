from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import (
    client_metadata,
    enforce_idempotency_header,
    get_current_user,
)
from app.core.enums import TransactionType
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.transaction import (
    RepaymentListResponse,
    TransactionCreateResponse,
    TypedTransactionCreate,
)
from app.services import ledger_service, transaction_service

router = APIRouter(prefix="/repayments", tags=["repayments"])


@router.get("", response_model=RepaymentListResponse)
def list_repayments(
    loan_id: int | None = Query(default=None, gt=0),
    limit: int = Query(default=50, ge=1, le=500),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RepaymentListResponse:
    return ledger_service.list_repayments(
        db, user, loan_id=loan_id, limit=limit
    )


@router.post("", response_model=TransactionCreateResponse, status_code=201)
def create_repayment(
    payload: TypedTransactionCreate,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TransactionCreateResponse:
    enforce_idempotency_header(request, payload.request_id)
    ip_address, user_agent = client_metadata(request)
    return transaction_service.create_transaction(
        db,
        user,
        payload,
        transaction_type=TransactionType.REPAYMENT,
        ip_address=ip_address,
        user_agent=user_agent,
    )
