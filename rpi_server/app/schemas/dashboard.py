from __future__ import annotations

from pydantic import Field

from app.core.enums import LoanKind
from app.schemas.common import APIModel, UtcDateTime
from app.schemas.transaction import TransactionOut


class CategoryBreakdownOut(APIModel):
    category_id: str = ""
    name: str = "Uncategorised"
    amount: float = 0
    percentage: float = 0
    color_hex: str = "#64748B"
    icon_key: str = "category"


class UpcomingRepaymentOut(APIModel):
    id: str
    loan_id: str
    person_name: str = "Unknown person"
    amount: float = 0
    due_date: str
    direction: str
    kind: LoanKind


class LedgerNoteOut(APIModel):
    id: str
    title: str
    body: str
    created_at: UtcDateTime | None = None
    pinned: bool = False


class DashboardSummaryOut(APIModel):
    available_balance: float
    total_income: float
    total_expenses: float
    total_savings: float
    money_lent: float
    money_borrowed: float
    outstanding_lent: float
    outstanding_borrowed: float
    upcoming_repayment_total: float
    upcoming_repayment_count: int
    recent_transactions: list[TransactionOut]
    category_breakdown: list[CategoryBreakdownOut]
    upcoming_repayments: list[UpcomingRepaymentOut]
    notes: list[LedgerNoteOut]
    currency: str = "INR"


class DashboardResponse(APIModel):
    success: bool = True
    summary: DashboardSummaryOut


class CalendarDayOut(APIModel):
    date: str
    income: float = 0
    expense: float = 0
    savings: float = 0
    lending: float = 0
    borrowing: float = 0
    repayment: float = 0
    transaction_count: int = 0
    transactions: list[TransactionOut] = Field(default_factory=list)


class CalendarMonthResponse(APIModel):
    success: bool = True
    month: str
    days: list[CalendarDayOut]
