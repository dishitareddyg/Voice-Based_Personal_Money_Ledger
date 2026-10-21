"""Idempotent startup tasks (bootstrap administrator, Mongo indexes)."""

from __future__ import annotations

import logging

from app.core.config import get_settings
from app.core.enums import UserRole
from app.core.security import hash_password
from app.database.mysql.session import SessionLocal
from app.repositories import user_repository

logger = logging.getLogger(__name__)


def bootstrap_admin() -> None:
    settings = get_settings()
    if not settings.admin_email or not settings.admin_password:
        return
    if len(settings.admin_password) < settings.password_min_length:
        logger.warning(
            "Admin bootstrap skipped: ADMIN_PASSWORD is shorter than %s characters.",
            settings.password_min_length,
        )
        return

    with SessionLocal() as db:
        existing = user_repository.get_by_email(db, settings.admin_email)
        if existing is not None:
            if not existing.is_admin:
                existing.role = UserRole.ADMIN.value
                db.commit()
                logger.info(
                    "Promoted bootstrap account %s to administrator.",
                    settings.admin_email,
                )
            return

        user_repository.create(
            db,
            full_name=settings.admin_full_name,
            email=settings.admin_email,
            password_hash=hash_password(settings.admin_password),
            role=UserRole.ADMIN,
            timezone=settings.default_timezone,
        )
        db.commit()
        logger.info(
            "Created bootstrap administrator %s.", settings.admin_email
        )
