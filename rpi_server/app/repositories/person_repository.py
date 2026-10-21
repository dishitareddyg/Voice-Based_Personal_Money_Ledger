from __future__ import annotations

from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.enums import LoanKind, LoanStatus
from app.models.loan import Loan
from app.models.person import Person
from app.models.transaction import Transaction


def get(db: Session, user_id: int, person_id: int) -> Person | None:
    return db.scalar(
        select(Person).where(
            Person.id == person_id, Person.user_id == user_id
        )
    )


def get_by_name(
    db: Session, user_id: int, name: str
) -> Person | None:
    return db.scalar(
        select(Person).where(
            Person.user_id == user_id,
            func.lower(Person.name) == name.strip().lower(),
        )
    )


def list_all(
    db: Session, user_id: int, *, search: str | None = None
) -> list[Person]:
    stmt = select(Person).where(Person.user_id == user_id)
    if search:
        stmt = stmt.where(Person.name.ilike(f"%{search.strip()}%"))
    return list(db.scalars(stmt.order_by(Person.name.asc())))


def create(
    db: Session,
    *,
    user_id: int,
    name: str,
    phone: str | None = None,
    email: str | None = None,
    notes: str | None = None,
) -> Person:
    person = Person(
        user_id=user_id,
        name=name.strip(),
        phone=phone,
        email=email,
        notes=notes,
    )
    db.add(person)
    db.flush()
    return person


def update(db: Session, person: Person, **values: object) -> Person:
    for field, value in values.items():
        if value is not None:
            setattr(person, field, value)
    db.flush()
    return person


def delete(db: Session, person: Person) -> None:
    db.delete(person)
    db.flush()


def has_transactions(db: Session, user_id: int, person_id: int) -> bool:
    return bool(
        db.scalar(
            select(func.count(Transaction.id))
            .where(
                Transaction.user_id == user_id,
                Transaction.person_id == person_id,
            )
            .limit(1)
        )
    )


def outstanding_totals(
    db: Session, user_id: int
) -> dict[int, tuple[Decimal, Decimal]]:
    """person_id -> (outstanding_lent, outstanding_borrowed)."""
    rows = db.execute(
        select(
            Loan.person_id,
            Loan.kind,
            func.coalesce(func.sum(Loan.outstanding_amount_inr), 0),
        )
        .where(
            Loan.user_id == user_id,
            Loan.status == LoanStatus.OPEN.value,
        )
        .group_by(Loan.person_id, Loan.kind)
    ).all()
    totals: dict[int, list[Decimal]] = {}
    for person_id, kind, amount in rows:
        bucket = totals.setdefault(person_id, [Decimal("0"), Decimal("0")])
        if kind == LoanKind.LENT.value:
            bucket[0] = Decimal(amount)
        else:
            bucket[1] = Decimal(amount)
    return {pid: (values[0], values[1]) for pid, values in totals.items()}


def outstanding_for_person(
    db: Session, user_id: int, person_id: int, kind: LoanKind
) -> Decimal:
    value = db.scalar(
        select(
            func.coalesce(func.sum(Loan.outstanding_amount_inr), 0)
        ).where(
            Loan.user_id == user_id,
            Loan.person_id == person_id,
            Loan.kind == kind.value,
            Loan.status == LoanStatus.OPEN.value,
        )
    )
    return Decimal(value or 0)
