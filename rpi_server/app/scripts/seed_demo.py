"""Seed a realistic Indian demo account.

Usage:
    python -m app.scripts.seed_demo

The demo credentials are printed at the end. Running the script twice is safe:
it exits when the demo user already has transactions. All financial writes go
through ``transaction_service`` so balances, loans and repayments obey the same
business rules as the API.
"""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import func, select

from app.core.enums import (
    CompoundingFrequency,
    InterestType,
    TransactionType,
)
from app.core.security import hash_password
from app.core.time import today_in_timezone
from app.database.mysql.session import SessionLocal
from app.models.category import Category
from app.models.interest_scheme import InterestScheme
from app.models.transaction import Transaction
from app.models.user import User
from app.repositories import category_repository, user_repository
from app.schemas.transaction import TransactionCreate
from app.services import directory_service, transaction_service

DEMO_EMAIL = "demo@voiceledger.in"
DEMO_PASSWORD = "Demo@12345"
DEMO_NAME = "Demo User"

_CATEGORIES = (
    ("Food", TransactionType.EXPENSE, "#E76F51", "restaurant"),
    ("Groceries", TransactionType.EXPENSE, "#F4A261", "shopping_basket"),
    ("Transport", TransactionType.EXPENSE, "#457B9D", "directions_bus"),
    ("Education", TransactionType.EXPENSE, "#6D597A", "school"),
    ("Bills", TransactionType.EXPENSE, "#B56576", "receipt_long"),
    ("Entertainment", TransactionType.EXPENSE, "#9B5DE5", "movie"),
    ("Healthcare", TransactionType.EXPENSE, "#2A9D8F", "local_hospital"),
    ("Shopping", TransactionType.EXPENSE, "#E9C46A", "shopping_bag"),
    ("Salary", TransactionType.INCOME, "#2A9D8F", "payments"),
    ("Freelance", TransactionType.INCOME, "#43AA8B", "work"),
    ("Savings", TransactionType.SAVINGS, "#E9C46A", "savings"),
)

_PERSONS = (
    ("Ravi Kumar", "+91-90000-00001", "Friend"),
    ("Asha Patel", "+91-90000-00002", "Colleague"),
    ("Priya Sharma", "+91-90000-00003", "Neighbour"),
    ("Arjun Mehta", "+91-90000-00004", "Family"),
)


def main() -> None:
    with SessionLocal() as db:
        user = user_repository.get_by_email(db, DEMO_EMAIL)
        if user is None:
            user = user_repository.create(
                db,
                full_name=DEMO_NAME,
                email=DEMO_EMAIL,
                password_hash=hash_password(DEMO_PASSWORD),
            )
            db.commit()
            db.refresh(user)
            print(f"Created demo user {DEMO_EMAIL}.")
        else:
            existing = db.scalar(
                select(func.count(Transaction.id)).where(
                    Transaction.user_id == user.id
                )
            )
            if existing:
                print("Demo data already exists; nothing to do.")
                return

        categories = _ensure_categories(db, user)
        _ensure_interest_scheme(db, user)
        _ensure_persons(db, user)
        today = today_in_timezone(user.timezone)

        # Income ------------------------------------------------------------
        _create(
            db,
            user,
            TransactionType.INCOME,
            "75000.00",
            transaction_date=today - timedelta(days=25),
            description="Monthly salary",
            category_id=categories["Salary"].id,
        )
        _create(
            db,
            user,
            TransactionType.INCOME,
            "18000.00",
            transaction_date=today - timedelta(days=12),
            description="Freelance website project",
            category_id=categories["Freelance"].id,
        )

        # Expenses ----------------------------------------------------------
        for days, amount, description, category in (
            (20, "1250.00", "Family dinner", "Food"),
            (18, "4300.00", "Monthly groceries", "Groceries"),
            (15, "900.00", "Metro and auto fares", "Transport"),
            (14, "2200.00", "Electricity and internet", "Bills"),
            (9, "1500.00", "Movie tickets", "Entertainment"),
            (8, "3000.00", "Pharmacy and consultation", "Healthcare"),
            (6, "2600.00", "Clothing", "Shopping"),
            (3, "6000.00", "Online course fee", "Education"),
        ):
            _create(
                db,
                user,
                TransactionType.EXPENSE,
                amount,
                transaction_date=today - timedelta(days=days),
                description=description,
                category_id=categories[category].id,
            )

        # Savings -----------------------------------------------------------
        _create(
            db,
            user,
            TransactionType.SAVINGS,
            "10000.00",
            transaction_date=today - timedelta(days=11),
            description="Emergency fund",
            category_id=categories["Savings"].id,
        )

        # Loans -------------------------------------------------------------
        _create(
            db,
            user,
            TransactionType.LENDING,
            "5000.00",
            transaction_date=today - timedelta(days=16),
            description="Short-term loan to Ravi",
            person_name="Ravi Kumar",
            due_date=today + timedelta(days=14),
            interest_rate=Decimal("8.5"),
            interest_type=InterestType.SIMPLE,
        )
        _create(
            db,
            user,
            TransactionType.BORROWING,
            "8000.00",
            transaction_date=today - timedelta(days=13),
            description="Borrowed for laptop repair",
            person_name="Asha Patel",
            due_date=today + timedelta(days=20),
        )
        _create(
            db,
            user,
            TransactionType.LENDING,
            "2500.00",
            transaction_date=today - timedelta(days=7),
            description="Loan to Priya for books",
            person_name="Priya Sharma",
            due_date=today + timedelta(days=30),
            interest_rate=Decimal("10"),
            interest_type=InterestType.COMPOUND,
        )

        # Repayments --------------------------------------------------------
        _create(
            db,
            user,
            TransactionType.REPAYMENT,
            "2000.00",
            transaction_date=today - timedelta(days=5),
            description="Ravi repaid part of the loan",
            person_name="Ravi Kumar",
            repayment_direction="received",
        )
        _create(
            db,
            user,
            TransactionType.REPAYMENT,
            "1500.00",
            transaction_date=today - timedelta(days=4),
            description="Paid Asha part of the borrowed amount",
            person_name="Asha Patel",
            repayment_direction="paid",
        )

        print("Demo ledger seeded.")
        print(f"  email:    {DEMO_EMAIL}")
        print(f"  password: {DEMO_PASSWORD}")


def _ensure_categories(db, user: User) -> dict[str, Category]:
    existing = {
        (category.name, category.type): category
        for category in category_repository.list_all(db, user.id)
    }
    result: dict[str, Category] = {}
    for name, type_value, color, icon in _CATEGORIES:
        key = (name, type_value.value)
        category = existing.get(key)
        if category is None:
            category = category_repository.create(
                db,
                user_id=user.id,
                name=name,
                type_value=type_value.value,
                color_hex=color,
                icon_key=icon,
            )
        result[name] = category
    db.commit()
    return result


def _ensure_persons(db, user: User) -> None:
    for name, phone, notes in _PERSONS:
        person = directory_service.ensure_person(
            db, user.id, person_id=None, person_name=name
        )
        if person.phone is None:
            person.phone = phone
        if person.notes is None:
            person.notes = notes
    db.commit()


def _ensure_interest_scheme(db, user: User) -> None:
    existing = db.scalar(
        select(InterestScheme).where(
            InterestScheme.user_id == user.id,
            InterestScheme.name == "Family loan 8.5%",
        )
    )
    if existing is None:
        db.add(
            InterestScheme(
                user_id=user.id,
                name="Family loan 8.5%",
                rate=Decimal("8.500"),
                interest_type=InterestType.SIMPLE.value,
                compounding_frequency=CompoundingFrequency.NONE.value,
                description="Simple interest for informal family loans.",
                is_active=True,
            )
        )
        db.commit()


def _create(
    db,
    user: User,
    transaction_type: TransactionType,
    amount: str,
    *,
    transaction_date,
    description: str,
    category_id: int | None = None,
    person_name: str | None = None,
    repayment_direction: str | None = None,
    due_date=None,
    interest_rate: Decimal | None = None,
    interest_type: InterestType | None = None,
) -> None:
    payload = TransactionCreate(
        request_id=uuid4().hex,
        type=transaction_type,
        amount=Decimal(amount),
        currency="INR",
        transaction_date=transaction_date,
        description=description,
        category_id=category_id,
        person_name=person_name,
        repayment_direction=repayment_direction,
        due_date=due_date,
        interest_rate=interest_rate,
        interest_type=interest_type,
    )
    transaction_service.create_transaction(
        db, user, payload, transaction_type=transaction_type
    )


if __name__ == "__main__":
    main()
