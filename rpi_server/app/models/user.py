from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import UserRole
from app.core.time import utc_now_naive
from app.database.mysql.base import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "role IN ('user', 'admin')", name="ck_users_role"
        ),
        CheckConstraint(
            "CHAR_LENGTH(TRIM(full_name)) > 0", name="ck_users_full_name"
        ),
        CheckConstraint(
            "CHAR_LENGTH(TRIM(timezone)) > 0", name="ck_users_timezone"
        ),
    )

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True
    )
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True, index=True
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(
        String(20), nullable=False, default=UserRole.USER.value
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    timezone: Mapped[str] = mapped_column(
        String(64), nullable=False, default="Asia/Kolkata"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utc_now_naive
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now_naive,
        onupdate=utc_now_naive,
    )

    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN.value
