from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.dashboard import DashboardResponse
from app.services import dashboard_service

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/summary", response_model=DashboardResponse)
def summary(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DashboardResponse:
    return dashboard_service.get_summary(db, user)
