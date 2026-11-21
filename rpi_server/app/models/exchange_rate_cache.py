"""``EXCHANGE_RATE_CACHE``: short-lived foreign-exchange rate cache.

Replaces the former ``exchange_rates`` document collection. One row per
currency pair; a refresh overwrites the row. The cache is optional: the
external provider remains canonical (see ``currency_service``).

Rates are ``DECIMAL`` end to end; floats are never used for money.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Index,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.mysql import DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.database.mysql.base import Base

# 16 integer digits, 12 fractional digits.
RATE_PRECISION = 28
RATE_SCALE = 12


class ExchangeRateCache(Base):
    __tablename__ = "EXCHANGE_RATE_CACHE"
    __table_args__ = (
        # Lookup key and upsert target: one cached rate per pair.
        UniqueConstraint(
            "base_currency",
            "target_currency",
            name="uq_exchange_rate_cache_pair",
        ),
        CheckConstraint("rate > 0", name="ck_exchange_rate_cache_rate"),
        CheckConstraint(
            "CHAR_LENGTH(base_currency) = 3 "
            "AND CHAR_LENGTH(target_currency) = 3",
            name="ck_exchange_rate_cache_currency",
        ),
        CheckConstraint(
            "valid_until >= retrieved_at",
            name="ck_exchange_rate_cache_validity",
        ),
        # Supports pruning of expired rows.
        Index("ix_exchange_rate_cache_valid_until", "valid_until"),
        {
            "mysql_engine": "InnoDB",
            "mysql_charset": "utf8mb4",
            "mysql_collate": "utf8mb4_0900_ai_ci",
        },
    )

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True
    )
    base_currency: Mapped[str] = mapped_column(String(3), nullable=False)
    target_currency: Mapped[str] = mapped_column(String(3), nullable=False)
    rate: Mapped[Decimal] = mapped_column(
        Numeric(RATE_PRECISION, RATE_SCALE, asdecimal=True), nullable=False
    )
    provider: Mapped[str] = mapped_column(String(255), nullable=False)
    retrieved_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=6), nullable=False
    )
    valid_until: Mapped[datetime] = mapped_column(
        DATETIME(fsp=6), nullable=False
    )
