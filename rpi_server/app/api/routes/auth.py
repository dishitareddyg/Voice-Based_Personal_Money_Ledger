from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.deps import client_metadata, get_current_user
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    MeResponse,
    MessageResponse,
    RegisterRequest,
    UserOut,
)
from app.schemas.user import PasswordChangeRequest, UserUpdateRequest
from app.services import audit_service, auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=201)
def register(
    payload: RegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, token = auth_service.register(db, payload)
    ip_address, user_agent = client_metadata(request)
    audit_service.record_event(
        "user_registered",
        user_id=user.id,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    audit_service.record_application_event(
        "auth_registered",
        user_id=user.id,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    return AuthResponse(
        access_token=token, user=UserOut.model_validate(user)
    )


@router.post("/login", response_model=AuthResponse)
def login(
    payload: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, token = auth_service.login(db, payload.email, payload.password)
    ip_address, user_agent = client_metadata(request)
    audit_service.record_event(
        "user_login",
        user_id=user.id,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    audit_service.record_application_event(
        "auth_login",
        user_id=user.id,
        ip_address=ip_address,
        user_agent=user_agent,
    )
    return AuthResponse(
        access_token=token, user=UserOut.model_validate(user)
    )


@router.get("/me", response_model=MeResponse)
def me(user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(user=UserOut.model_validate(user))


@router.patch("/me", response_model=MeResponse)
def update_me(
    payload: UserUpdateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MeResponse:
    updated = auth_service.update_profile(db, user, payload)
    return MeResponse(user=UserOut.model_validate(updated))


@router.post("/change-password", response_model=MessageResponse)
def change_password(
    payload: PasswordChangeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    auth_service.change_password(db, user, payload)
    return MessageResponse(message="Password updated successfully.")


@router.post("/logout", response_model=MessageResponse)
def logout(_: User = Depends(get_current_user)) -> MessageResponse:
    """JWTs are stateless; the client discards its token."""
    return MessageResponse(message="Signed out.")
