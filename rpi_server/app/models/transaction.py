from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import TransactionStatus
from app.core.time import utc_now_naive
from app.database.mysql.base import Base
from app.models.category import Category
from app.models.loan import Loan
from app.models.person import Person


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "request_id", name="uq_transactions_user_request"
        ),
        CheckConstraint(
            "type IN ('income', 'expense', 'savings', 'lending', "
            "'borrowing', 'repayment')",
            name="ck_transactions_type",
        ),
        CheckConstraint(
            "amount_inr > 0", name="ck_transactions_amount_positive"
        ),
        CheckConstraint(
            "original_amount IS NULL OR original_amount > 0",
            name="ck_transactions_original_amount_positive",
        ),
        CheckConstraint(
            "original_currency IS NULL "
            "OR CHAR_LENGTH(original_currency) = 3",
            name="ck_transactions_original_currency",
        ),
        CheckConstraint(
            "exchange_rate_to_inr IS NULL OR exchange_rate_to_inr > 0",
            name="ck_transactions_exchange_rate_positive",
        ),
        CheckConstraint(
            "repayment_direction IS NULL "
            "OR repayment_direction IN ('received', 'paid')",
            name="ck_transactions_direction",
        ),
        CheckConstraint(
            "interest_rate IS NULL "
            "OR (interest_rate >= 0 AND interest_rate <= 100)",
            name="ck_transactions_interest_rate",
        ),
        CheckConstraint(
            "status IN ('completed', 'reversed')",
            name="ck_transactions_status",
        ),
        CheckConstraint(
            "CHAR_LENGTH(request_id) >= 8",
            name="ck_transactions_request_id_length",
        ),
        Index("ix_transactions_user_date", "user_id", "transaction_date"),
        Index(
            "ix_transactions_user_date_id",
            "user_id",
            "transaction_date",
            "id",
        ),
        Index("ix_transactions_user_type", "user_id", "type"),
        Index("ix_transactions_user_category", "user_id", "category_id"),
        Index("ix_transactions_user_person", "user_id", "person_id"),
        Index("ix_transactions_user_loan", "user_id", "loan_id"),
        Index("ix_transactions_request_id", "request_id"),
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
    type: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    amount_inr: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)
    original_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(15, 2), nullable=True
    )
    original_currency: Mapped[str | None] = mapped_column(
        String(3), nullable=True
    )
    exchange_rate_to_inr: Mapped[Decimal | None] = mapped_column(
        Numeric(18, 8), nullable=True
    )
    transaction_date: Mapped[date] = mapped_column(
        Date, nullable=False, index=True
    )
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    category_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    person_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("persons.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    loan_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("loans.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    repayment_direction: Mapped[str | None] = mapped_column(
        String(10), nullable=True
    )
    interest_rate: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 3), nullable=True
    )
    interest_type: Mapped[str | None] = mapped_column(
        String(20), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=TransactionStatus.COMPLETED.value
    )
    request_id: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utc_now_naive
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now_naive,
        onupdate=utc_now_naive,
    )

    category: Mapped[Category | None] = relationship(lazy="joined")
    person: Mapped[Person | None] = relationship(lazy="joined")
    loan: Mapped[Loan | None] = relationship(
        foreign_keys="Transaction.loan_id", lazy="joined"
    )

    @property
    def category_name(self) -> str | None:
        return self.category.name if self.category is not None else None

    @property
    def person_name(self) -> str | None:
        return self.person.name if self.person is not None else None

    @property
    def currency(self) -> str:
        return self.original_currency or "INR"
