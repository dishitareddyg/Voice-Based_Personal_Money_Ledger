from __future__ import annotations

from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy.orm import Session

from app.business_rules.financial_rules import quantize_money
from app.core.enums import LoanKind
from app.core.time import today_in_timezone
from app.models.loan import Loan
from app.models.user import User
from app.repositories import loan_repository, transaction_repository
from app.schemas.dashboard import (
    CategoryBreakdownOut,
    DashboardResponse,
    DashboardSummaryOut,
    LedgerNoteOut,
    UpcomingRepaymentOut,
)
from app.schemas.transaction import TransactionOut
from app.services import balance_service

_UPCOMING_WINDOW_DAYS = 30
_NOTES_WINDOW_DAYS = 7


def get_summary(db: Session, user: User) -> DashboardResponse:
    values = balance_service.totals(db, user.id)
    balance = (
        values["income"]
        + values["borrowing"]
        + values["repayment_received"]
        - values["expense"]
        - values["savings"]
        - values["lending"]
        - values["repayment_paid"]
    )
    available = quantize_money(balance)

    today = today_in_timezone(user.timezone)
    horizon = today + timedelta(days=_UPCOMING_WINDOW_DAYS)
    month_start = today.replace(day=1)

    outstanding = loan_repository.outstanding_by_kind(db, user.id)
    principal = loan_repository.principal_by_kind(db, user.id)
    upcoming_total, upcoming_count = loan_repository.upcoming_totals(
        db, user.id, date_from=today, date_to=horizon
    )
    upcoming_loans = loan_repository.upcoming(
        db, user.id, date_from=today, date_to=horizon, limit=5
    )

    breakdown_rows = transaction_repository.category_breakdown(
        db, user.id, date_from=month_start, date_to=today
    )
    breakdown_total = sum(
        (amount for *_, amount in breakdown_rows), Decimal("0")
    )
    breakdown: list[CategoryBreakdownOut] = []
    for category_id, name, color, icon, amount in breakdown_rows:
        percentage = (
            float(amount) / float(breakdown_total) * 100
            if breakdown_total > 0
            else 0
        )
        breakdown.append(
            CategoryBreakdownOut(
                category_id=str(category_id) if category_id is not None else "",
                name=name or "Uncategorised",
                amount=float(amount),
                percentage=round(percentage, 2),
                color_hex=color or "#64748B",
                icon_key=icon or "category",
            )
        )

    recent = transaction_repository.recent(db, user.id, limit=5)

    return DashboardResponse(
        summary=DashboardSummaryOut(
            available_balance=float(available),
            total_income=float(values["income"]),
            total_expenses=float(values["expense"]),
            total_savings=float(values["savings"]),
            money_lent=float(
                principal.get(LoanKind.LENT, Decimal("0"))
            ),
            money_borrowed=float(
                principal.get(LoanKind.BORROWED, Decimal("0"))
            ),
            outstanding_lent=float(
                outstanding.get(LoanKind.LENT, Decimal("0"))
            ),
            outstanding_borrowed=float(
                outstanding.get(LoanKind.BORROWED, Decimal("0"))
            ),
            upcoming_repayment_total=float(upcoming_total),
            upcoming_repayment_count=upcoming_count,
            recent_transactions=[
                TransactionOut.model_validate(item) for item in recent
            ],
            category_breakdown=breakdown,
            upcoming_repayments=[
                _upcoming_out(loan) for loan in upcoming_loans
            ],
            notes=_notes(
                db, user, today + timedelta(days=_NOTES_WINDOW_DAYS)
            ),
            currency="INR",
        )
    )


def _upcoming_out(loan: Loan) -> UpcomingRepaymentOut:
    assert loan.due_date is not None
    lent = loan.kind == LoanKind.LENT.value
    return UpcomingRepaymentOut(
        id=str(loan.id),
        loan_id=str(loan.id),
        person_name=loan.person_name or "Unknown person",
        amount=float(loan.outstanding_amount_inr),
        due_date=loan.due_date.isoformat(),
        direction="received" if lent else "paid",
        kind=LoanKind(loan.kind),
    )


def _notes(db: Session, user: User, until: date) -> list[LedgerNoteOut]:
    today = today_in_timezone(user.timezone)
    loans = loan_repository.upcoming(
        db, user.id, date_from=today, date_to=until, limit=5
    )
    notes: list[LedgerNoteOut] = []
    for loan in loans:
        assert loan.due_date is not None
        lent = loan.kind == LoanKind.LENT.value
        preposition = "from" if lent else "to"
        notes.append(
            LedgerNoteOut(
                id=f"loan-{loan.id}",
                title="Repayment due",
                body=(
                    f"INR {float(loan.outstanding_amount_inr):,.2f} "
                    f"{preposition} {loan.person_name or 'someone'} "
                    f"is due on {loan.due_date.isoformat()}."
                ),
            )
        )
    return notes
