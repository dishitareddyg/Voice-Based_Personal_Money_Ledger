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

from app.core.enums import InterestType, LoanKind, LoanStatus
from app.core.time import utc_now_naive
from app.database.mysql.base import Base
from app.models.person import Person


class Loan(Base):
    __tablename__ = "loans"
    __table_args__ = (
        UniqueConstraint(
            "source_transaction_id", name="uq_loans_source_transaction"
        ),
        CheckConstraint(
            "kind IN ('lent', 'borrowed')", name="ck_loans_kind"
        ),
        CheckConstraint(
            "status IN ('open', 'closed')", name="ck_loans_status"
        ),
        CheckConstraint(
            "principal_amount_inr > 0", name="ck_loans_principal_positive"
        ),
        CheckConstraint(
            "outstanding_amount_inr >= 0",
            name="ck_loans_outstanding_nonnegative",
        ),
        CheckConstraint(
            "interest_rate >= 0 AND interest_rate <= 100",
            name="ck_loans_interest_rate",
        ),
        CheckConstraint(
            "interest_type IN ('simple', 'compound', 'flat')",
            name="ck_loans_interest_type",
        ),
        CheckConstraint(
            "due_date IS NULL OR due_date >= start_date",
            name="ck_loans_due_after_start",
        ),
        Index("ix_loans_user_status", "user_id", "status"),
        Index("ix_loans_user_kind_status", "user_id", "kind", "status"),
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
    person_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("persons.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    # Added with ALTER TABLE after both tables exist (circular FK).
    source_transaction_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey(
            "transactions.id",
            ondelete="SET NULL",
            use_alter=True,
            name="fk_loans_source_transaction",
        ),
        nullable=True,
    )
    kind: Mapped[str] = mapped_column(String(10), nullable=False, index=True)
    principal_amount_inr: Mapped[Decimal] = mapped_column(
        Numeric(15, 2), nullable=False
    )
    outstanding_amount_inr: Mapped[Decimal] = mapped_column(
        Numeric(15, 2), nullable=False
    )
    interest_rate: Mapped[Decimal] = mapped_column(
        Numeric(6, 3), nullable=False, default=Decimal("0")
    )
    interest_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default=InterestType.SIMPLE.value
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=LoanStatus.OPEN.value, index=True
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utc_now_naive
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now_naive,
        onupdate=utc_now_naive,
    )

    person: Mapped[Person] = relationship(lazy="joined")

    @property
    def is_open(self) -> bool:
        return self.status == LoanStatus.OPEN.value

    @property
    def is_lent(self) -> bool:
        return self.kind == LoanKind.LENT.value

    @property
    def person_name(self) -> str | None:
        return self.person.name if self.person is not None else None
