from __future__ import annotations

from datetime import date

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
    TransactionCreateResponse,
    TransactionListResponse,
    TypedTransactionCreate,
)
from app.services import transaction_service


def build_typed_router(
    transaction_type: TransactionType, *, prefix: str, tag: str
) -> APIRouter:
    """Create list/create endpoints whose type is fixed by the URL."""

    router = APIRouter(prefix=prefix, tags=[tag])

    @router.post("", response_model=TransactionCreateResponse, status_code=201)
    def create(
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
            transaction_type=transaction_type,
            ip_address=ip_address,
            user_agent=user_agent,
        )

    @router.get("", response_model=TransactionListResponse)
    def list_items(
        page: int = Query(default=1, ge=1),
        page_size: int = Query(default=20, ge=1, le=100),
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
            type_value=transaction_type.value,
            search=search,
            date_from=date_from,
            date_to=date_to,
            person_id=person_id,
            category_id=category_id,
        )

    return router
