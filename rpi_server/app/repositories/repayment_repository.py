from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.repayment import Repayment


def create(db: Session, **values: object) -> Repayment:
    repayment = Repayment(**values)
    db.add(repayment)
    db.flush()
    return repayment


def list_all(
    db: Session,
    user_id: int,
    *,
    limit: int = 100,
    loan_id: int | None = None,
) -> list[Repayment]:
    stmt = select(Repayment).where(Repayment.user_id == user_id)
    if loan_id is not None:
        stmt = stmt.where(Repayment.loan_id == loan_id)
    stmt = stmt.order_by(
        Repayment.payment_date.desc(), Repayment.id.desc()
    ).limit(limit)
    return list(db.scalars(stmt))
