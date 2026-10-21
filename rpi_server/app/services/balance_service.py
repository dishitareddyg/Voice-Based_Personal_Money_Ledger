from __future__ import annotations

from decimal import Decimal

from sqlalchemy.orm import Session

from app.business_rules.financial_rules import quantize_money
from app.repositories import transaction_repository


def totals(db: Session, user_id: int) -> dict[str, Decimal]:
    return transaction_repository.totals(db, user_id)


def available_balance(db: Session, user_id: int) -> Decimal:
    values = transaction_repository.totals(db, user_id)
    balance = (
        values["income"]
        + values["borrowing"]
        + values["repayment_received"]
        - values["expense"]
        - values["savings"]
        - values["lending"]
        - values["repayment_paid"]
    )
    return quantize_money(balance)
