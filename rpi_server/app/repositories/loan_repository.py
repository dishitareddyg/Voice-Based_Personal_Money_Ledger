from __future__ import annotations

from datetime import date
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.core.enums import LoanKind, LoanStatus
from app.models.loan import Loan


def create(db: Session, **values: object) -> Loan:
    loan = Loan(**values)
    db.add(loan)
    db.flush()
    return loan


def get(
    db: Session,
    user_id: int,
    loan_id: int,
    *,
    for_update: bool = False,
) -> Loan | None:
    stmt = select(Loan).where(
        Loan.id == loan_id, Loan.user_id == user_id
    )
    if for_update:
        stmt = stmt.with_for_update()
    return db.scalar(stmt)


def list_loans(
    db: Session,
    user_id: int,
    *,
    kind: LoanKind | None = None,
    status: str | None = None,
    person_id: int | None = None,
    limit: int = 100,
) -> list[Loan]:
    stmt = select(Loan).where(Loan.user_id == user_id)
    if kind is not None:
        stmt = stmt.where(Loan.kind == kind.value)
    if status is not None:
        stmt = stmt.where(Loan.status == status)
    if person_id is not None:
        stmt = stmt.where(Loan.person_id == person_id)
    stmt = stmt.order_by(
        case((Loan.status == LoanStatus.OPEN.value, 0), else_=1),
        Loan.start_date.desc(),
        Loan.id.desc(),
    ).limit(limit)
    return list(db.scalars(stmt))


def open_for_person(
    db: Session, user_id: int, person_id: int, kind: LoanKind
) -> list[Loan]:
    return list(
        db.scalars(
            select(Loan)
            .where(
                Loan.user_id == user_id,
                Loan.person_id == person_id,
                Loan.kind == kind.value,
                Loan.status == LoanStatus.OPEN.value,
            )
            .order_by(Loan.start_date.asc(), Loan.id.asc())
        )
    )


def all_open(db: Session, user_id: int) -> list[Loan]:
    return list(
        db.scalars(
            select(Loan)
            .where(
                Loan.user_id == user_id,
                Loan.status == LoanStatus.OPEN.value,
            )
            .order_by(Loan.due_date.asc(), Loan.id.asc())
        )
    )


def outstanding_by_kind(
    db: Session, user_id: int
) -> dict[LoanKind, Decimal]:
    rows = db.execute(
        select(
            Loan.kind,
            func.coalesce(func.sum(Loan.outstanding_amount_inr), 0),
        )
        .where(
            Loan.user_id == user_id,
            Loan.status == LoanStatus.OPEN.value,
        )
        .group_by(Loan.kind)
    ).all()
    result = {
        LoanKind.LENT: Decimal("0"),
        LoanKind.BORROWED: Decimal("0"),
    }
    for kind, total in rows:
        result[LoanKind(kind)] = Decimal(total or 0)
    return result


def principal_by_kind(
    db: Session, user_id: int
) -> dict[LoanKind, Decimal]:
    rows = db.execute(
        select(
            Loan.kind,
            func.coalesce(func.sum(Loan.principal_amount_inr), 0),
        )
        .where(Loan.user_id == user_id)
        .group_by(Loan.kind)
    ).all()
    result = {
        LoanKind.LENT: Decimal("0"),
        LoanKind.BORROWED: Decimal("0"),
    }
    for kind, total in rows:
        result[LoanKind(kind)] = Decimal(total or 0)
    return result


def upcoming(
    db: Session,
    user_id: int,
    *,
    date_from: date,
    date_to: date,
    limit: int = 10,
) -> list[Loan]:
    return list(
        db.scalars(
            select(Loan)
            .where(
                Loan.user_id == user_id,
                Loan.status == LoanStatus.OPEN.value,
                Loan.due_date.is_not(None),
                Loan.due_date >= date_from,
                Loan.due_date <= date_to,
            )
            .order_by(Loan.due_date.asc(), Loan.id.asc())
            .limit(limit)
        )
    )


def upcoming_totals(
    db: Session,
    user_id: int,
    *,
    date_from: date,
    date_to: date,
) -> tuple[Decimal, int]:
    row = db.execute(
        select(
            func.coalesce(func.sum(Loan.outstanding_amount_inr), 0),
            func.count(Loan.id),
        ).where(
            Loan.user_id == user_id,
            Loan.status == LoanStatus.OPEN.value,
            Loan.due_date.is_not(None),
            Loan.due_date >= date_from,
            Loan.due_date <= date_to,
        )
    ).one()
    return Decimal(row[0] or 0), int(row[1] or 0)


def count(db: Session, user_id: int) -> int:
    return int(
        db.scalar(
            select(func.count(Loan.id)).where(Loan.user_id == user_id)
        )
        or 0
    )
