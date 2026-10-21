from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import (
    client_metadata,
    enforce_idempotency_header,
    get_current_user,
)
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.transaction import (
    TransactionCreate,
    TransactionCreateResponse,
    TransactionListResponse,
    TransactionOut,
)
from app.services import transaction_service

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.post("", response_model=TransactionCreateResponse, status_code=201)
def create_transaction(
    payload: TransactionCreate,
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
        transaction_type=payload.type,
        ip_address=ip_address,
        user_agent=user_agent,
    )


@router.get("", response_model=TransactionListResponse)
def list_transactions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    type_value: str | None = Query(default=None, alias="type"),
    search: str | None = Query(default=None, max_length=120),
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    person_id: int | None = Query(default=None, gt=0),
    category_id: int | None = Query(default=None, gt=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TransactionListResponse:
    return transaction_service.list_transactions(
        db,
        user,
        page=page,
        page_size=page_size,
        type_value=type_value,
        search=search,
        date_from=date_from,
        date_to=date_to,
        person_id=person_id,
        category_id=category_id,
    )


@router.get("/{transaction_id}", response_model=TransactionOut)
def get_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TransactionOut:
    return transaction_service.get_transaction(db, user, transaction_id)
