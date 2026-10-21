from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.transaction import LoanListResponse
from app.services import ledger_service

router = APIRouter(prefix="/loans", tags=["loans"])


@router.get("", response_model=LoanListResponse)
def list_loans(
    kind: str | None = Query(default=None),
    status: str | None = Query(default=None),
    person_id: int | None = Query(default=None, gt=0),
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LoanListResponse:
    return ledger_service.list_loans(
        db,
        user,
        kind=kind,
        status=status,
        person_id=person_id,
        limit=limit,
    )
