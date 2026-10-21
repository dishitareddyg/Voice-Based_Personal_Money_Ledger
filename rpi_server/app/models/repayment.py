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
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import RepaymentDirection
from app.core.time import utc_now_naive
from app.database.mysql.base import Base
from app.models.loan import Loan
from app.models.person import Person
from app.models.transaction import Transaction


class Repayment(Base):
    __tablename__ = "repayments"
    __table_args__ = (
        CheckConstraint(
            "amount_inr > 0", name="ck_repayments_amount_positive"
        ),
        CheckConstraint(
            "direction IN ('received', 'paid')",
            name="ck_repayments_direction",
        ),
        CheckConstraint(
            "status IN ('completed', 'reversed')",
            name="ck_repayments_status",
        ),
        Index("ix_repayments_user_date", "user_id", "payment_date"),
        Index("ix_repayments_loan_date", "loan_id", "payment_date"),
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
    loan_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("loans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    transaction_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("transactions.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    person_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("persons.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    amount_inr: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)
    direction: Mapped[str] = mapped_column(String(10), nullable=False)
    payment_date: Mapped[date] = mapped_column(Date, nullable=False)
    notes: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="completed"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=utc_now_naive
    )

    loan: Mapped[Loan] = relationship(lazy="joined")
    person: Mapped[Person] = relationship(lazy="joined")
    transaction: Mapped[Transaction] = relationship(lazy="joined")

    @property
    def is_received(self) -> bool:
        return self.direction == RepaymentDirection.RECEIVED.value

    @property
    def person_name(self) -> str | None:
        return self.person.name if self.person is not None else None
