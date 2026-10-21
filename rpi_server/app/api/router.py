from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import (
    admin,
    auth,
    borrowing,
    calendar,
    categories,
    commands,
    dashboard,
    expenses,
    income,
    lending,
    loans,
    persons,
    repayments,
    savings,
    transactions,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(dashboard.router)
api_router.include_router(calendar.router)
api_router.include_router(transactions.router)
api_router.include_router(commands.router)
api_router.include_router(expenses.router)
api_router.include_router(income.router)
api_router.include_router(savings.router)
api_router.include_router(lending.router)
api_router.include_router(borrowing.router)
api_router.include_router(repayments.router)
api_router.include_router(loans.router)
api_router.include_router(persons.router)
api_router.include_router(categories.router)
api_router.include_router(admin.router)
