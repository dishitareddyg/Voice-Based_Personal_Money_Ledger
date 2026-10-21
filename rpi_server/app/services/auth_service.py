from __future__ import annotations

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.enums import ErrorCode, UserRole
from app.core.errors import AppError
from app.core.security import (
    create_access_token,
    hash_password,
    password_needs_rehash,
    verify_password,
)
from app.models.user import User
from app.repositories import user_repository
from app.schemas.auth import RegisterRequest
from app.schemas.user import PasswordChangeRequest, UserUpdateRequest


def register(db: Session, payload: RegisterRequest) -> tuple[User, str]:
    settings = get_settings()
    if len(payload.password) < settings.password_min_length:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            f"Password must be at least {settings.password_min_length} characters.",
            status_code=422,
        )
    if user_repository.get_by_email(db, payload.email) is not None:
        raise AppError(
            ErrorCode.EMAIL_ALREADY_EXISTS,
            "An account with this email already exists.",
            status_code=409,
        )

    user = user_repository.create(
        db,
        full_name=payload.full_name,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=UserRole.USER,
        timezone=payload.timezone,
    )
    db.commit()
    db.refresh(user)
    token = create_access_token(
        user_id=user.id, email=user.email, role=user.role
    )
    return user, token


def login(db: Session, email: str, password: str) -> tuple[User, str]:
    user = user_repository.get_by_email(db, email)
    if user is None or not verify_password(password, user.password_hash):
        raise AppError(
            ErrorCode.INVALID_CREDENTIALS,
            "Email or password is incorrect.",
            status_code=401,
        )
    if not user.is_active:
        raise AppError(
            ErrorCode.USER_INACTIVE,
            "This account has been disabled.",
            status_code=403,
        )

    if password_needs_rehash(user.password_hash):
        user.password_hash = hash_password(password)
        db.commit()

    token = create_access_token(
        user_id=user.id, email=user.email, role=user.role
    )
    return user, token


def update_profile(
    db: Session, user: User, payload: UserUpdateRequest
) -> User:
    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()
    if payload.timezone is not None:
        user.timezone = payload.timezone.strip()
    db.commit()
    db.refresh(user)
    return user


def change_password(
    db: Session, user: User, payload: PasswordChangeRequest
) -> None:
    settings = get_settings()
    if not verify_password(payload.current_password, user.password_hash):
        raise AppError(
            ErrorCode.INVALID_CREDENTIALS,
            "Current password is incorrect.",
            status_code=401,
        )
    if len(payload.new_password) < settings.password_min_length:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            f"Password must be at least {settings.password_min_length} characters.",
            status_code=422,
        )
    user.password_hash = hash_password(payload.new_password)
    db.commit()
