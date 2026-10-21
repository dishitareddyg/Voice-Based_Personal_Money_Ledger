from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.dashboard import CalendarMonthResponse
from app.services import calendar_service

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("", response_model=CalendarMonthResponse)
def month_view(
    month: str = Query(..., description="Month in YYYY-MM format"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CalendarMonthResponse:
    return calendar_service.get_month(db, user, month)
