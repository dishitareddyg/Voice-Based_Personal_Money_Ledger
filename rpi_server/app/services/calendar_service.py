from __future__ import annotations

import re
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.core.enums import ErrorCode, TransactionType
from app.core.errors import AppError
from app.models.user import User
from app.repositories import transaction_repository
from app.schemas.dashboard import (
    CalendarDayOut,
    CalendarMonthResponse,
)
from app.schemas.transaction import TransactionOut

_MONTH_PATTERN = re.compile(r"^(\d{4})-(\d{2})$")


def get_month(
    db: Session, user: User, month: str
) -> CalendarMonthResponse:
    start, end = _month_bounds(month)

    day_totals: dict[date, dict[str, float]] = {}
    counts: dict[date, int] = {}
    for day, type_value, _direction, total, count in (
        transaction_repository.daily_totals(
            db, user.id, date_from=start, date_to=end
        )
    ):
        bucket = day_totals.setdefault(
            day,
            {
                "income": 0.0,
                "expense": 0.0,
                "savings": 0.0,
                "lending": 0.0,
                "borrowing": 0.0,
                "repayment": 0.0,
            },
        )
        amount = float(total)
        if type_value == TransactionType.INCOME.value:
            bucket["income"] += amount
        elif type_value == TransactionType.EXPENSE.value:
            bucket["expense"] += amount
        elif type_value == TransactionType.SAVINGS.value:
            bucket["savings"] += amount
        elif type_value == TransactionType.LENDING.value:
            bucket["lending"] += amount
        elif type_value == TransactionType.BORROWING.value:
            bucket["borrowing"] += amount
        elif type_value == TransactionType.REPAYMENT.value:
            bucket["repayment"] += amount
        counts[day] = counts.get(day, 0) + int(count)

    by_day: dict[date, list[TransactionOut]] = {}
    for transaction in transaction_repository.for_range(
        db, user.id, date_from=start, date_to=end
    ):
        by_day.setdefault(transaction.transaction_date, []).append(
            TransactionOut.model_validate(transaction)
        )

    days: list[CalendarDayOut] = []
    for day in sorted(set(day_totals) | set(by_day)):
        bucket = day_totals.get(
            day,
            {
                "income": 0.0,
                "expense": 0.0,
                "savings": 0.0,
                "lending": 0.0,
                "borrowing": 0.0,
                "repayment": 0.0,
            },
        )
        days.append(
            CalendarDayOut(
                date=day.isoformat(),
                income=bucket["income"],
                expense=bucket["expense"],
                savings=bucket["savings"],
                lending=bucket["lending"],
                borrowing=bucket["borrowing"],
                repayment=bucket["repayment"],
                transaction_count=counts.get(day, len(by_day.get(day, []))),
                transactions=by_day.get(day, []),
            )
        )

    return CalendarMonthResponse(
        month=start.strftime("%Y-%m"), days=days
    )


def _month_bounds(value: str) -> tuple[date, date]:
    match = _MONTH_PATTERN.match((value or "").strip())
    if not match:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Month must be in YYYY-MM format.",
            status_code=422,
        )
    year, month = int(match.group(1)), int(match.group(2))
    if month < 1 or month > 12:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Month must be between 01 and 12.",
            status_code=422,
        )
    start = date(year, month, 1)
    next_month = (
        date(year + 1, 1, 1)
        if month == 12
        else date(year, month + 1, 1)
    )
    return start, next_month - timedelta(days=1)
