from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now_naive
from app.database.mysql.base import Base


class Category(Base):
    __tablename__ = "categories"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "name", "type", name="uq_categories_user_name_type"
        ),
        CheckConstraint(
            "type IN ('income', 'expense', 'savings', 'lending', "
            "'borrowing', 'repayment')",
            name="ck_categories_type",
        ),
        CheckConstraint(
            "CHAR_LENGTH(TRIM(name)) > 0", name="ck_categories_name"
        ),
        Index("ix_categories_user_type", "user_id", "type"),
    )

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    color_hex: Mapped[str] = mapped_column(
        String(9), nullable=False, default="#0E6B5C"
    )
    icon_key: Mapped[str] = mapped_column(
        String(40), nullable=False, default="category"
    )
    is_default: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
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
