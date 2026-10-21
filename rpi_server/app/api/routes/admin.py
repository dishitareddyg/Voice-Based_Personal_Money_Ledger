from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.deps import client_metadata, require_admin
from app.database.mysql.session import get_db
from app.models.user import User
from app.repositories import user_repository
from app.schemas.admin import AdminActionRequest, AdminActionResponse
from app.schemas.auth import UserOut
from app.schemas.user import UserListResponse
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/actions", response_model=AdminActionResponse)
def run_action(
    payload: AdminActionRequest,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> AdminActionResponse:
    ip_address, _ = client_metadata(request)
    return admin_service.run_action(
        db, admin, payload, ip_address=ip_address
    )


@router.get("/users", response_model=UserListResponse)
def list_users(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
) -> UserListResponse:
    return UserListResponse(
        users=[
            UserOut.model_validate(user)
            for user in user_repository.list_all(db)
        ]
    )
