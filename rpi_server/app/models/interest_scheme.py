from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import CompoundingFrequency, InterestType
from app.core.time import utc_now_naive
from app.database.mysql.base import Base


class InterestScheme(Base):
    """Optional reusable interest configuration (a DBMS demonstration table)."""

    __tablename__ = "interest_schemes"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_interest_schemes_user_name"),
        CheckConstraint(
            "rate >= 0 AND rate <= 100", name="ck_interest_schemes_rate"
        ),
        CheckConstraint(
            "interest_type IN ('simple', 'compound', 'flat')",
            name="ck_interest_schemes_type",
        ),
        CheckConstraint(
            "compounding_frequency IN "
            "('none', 'daily', 'monthly', 'quarterly', "
            "'half_yearly', 'yearly')",
            name="ck_interest_schemes_compounding",
        ),
        CheckConstraint(
            "CHAR_LENGTH(TRIM(name)) > 0",
            name="ck_interest_schemes_name",
        ),
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
    rate: Mapped[Decimal] = mapped_column(Numeric(6, 3), nullable=False)
    interest_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default=InterestType.SIMPLE.value
    )
    compounding_frequency: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=CompoundingFrequency.NONE.value,
    )
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
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
