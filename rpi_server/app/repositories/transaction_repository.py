from __future__ import annotations

from datetime import date
from decimal import Decimal

from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.orm import Session

from app.core.enums import RepaymentDirection, TransactionStatus, TransactionType
from app.models.category import Category
from app.models.person import Person
from app.models.transaction import Transaction


def create(db: Session, **values: object) -> Transaction:
    transaction = Transaction(**values)
    db.add(transaction)
    db.flush()
    return transaction


def get(
    db: Session, user_id: int, transaction_id: int
) -> Transaction | None:
    return db.scalar(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.user_id == user_id,
        )
    )


def get_by_request_id(
    db: Session, user_id: int, request_id: str
) -> Transaction | None:
    return db.scalar(
        select(Transaction).where(
            Transaction.user_id == user_id,
            Transaction.request_id == request_id,
        )
    )


def latest(db: Session, user_id: int) -> Transaction | None:
    return db.scalar(
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .order_by(Transaction.created_at.desc(), Transaction.id.desc())
        .limit(1)
    )


def recent(
    db: Session, user_id: int, *, limit: int = 10
) -> list[Transaction]:
    return list(
        db.scalars(
            select(Transaction)
            .where(Transaction.user_id == user_id)
            .order_by(
                Transaction.transaction_date.desc(),
                Transaction.id.desc(),
            )
            .limit(limit)
        )
    )


def _apply_filters(
    stmt,
    *,
    user_id: int,
    type_value: str | None,
    search: str | None,
    date_from: date | None,
    date_to: date | None,
    person_id: int | None,
    category_id: int | None,
):
    stmt = stmt.where(Transaction.user_id == user_id)
    if type_value is not None:
        stmt = stmt.where(Transaction.type == type_value)
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    if person_id is not None:
        stmt = stmt.where(Transaction.person_id == person_id)
    if category_id is not None:
        stmt = stmt.where(Transaction.category_id == category_id)
    if search:
        term = f"%{search.strip()}%"
        stmt = stmt.where(
            or_(
                Transaction.description.ilike(term),
                Transaction.category_id.in_(
                    select(Category.id).where(Category.name.ilike(term))
                ),
                Transaction.person_id.in_(
                    select(Person.id).where(Person.name.ilike(term))
                ),
            )
        )
    return stmt


def list_page(
    db: Session,
    user_id: int,
    *,
    page: int,
    page_size: int,
    type_value: str | None = None,
    search: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    person_id: int | None = None,
    category_id: int | None = None,
) -> tuple[list[Transaction], int]:
    filters = dict(
        user_id=user_id,
        type_value=type_value,
        search=search,
        date_from=date_from,
        date_to=date_to,
        person_id=person_id,
        category_id=category_id,
    )
    count_stmt = _apply_filters(
        select(func.count(Transaction.id)).select_from(Transaction), **filters
    )
    total = int(db.scalar(count_stmt) or 0)

    items_stmt = _apply_filters(select(Transaction), **filters).order_by(
        Transaction.transaction_date.desc(),
        Transaction.id.desc(),
    )
    items = list(
        db.scalars(
            items_stmt.offset((page - 1) * page_size).limit(page_size)
        )
    )
    return items, total


def totals(db: Session, user_id: int) -> dict[str, Decimal]:
    def _sum(
        type_value: TransactionType,
        direction: RepaymentDirection | None = None,
    ):
        conditions = [
            Transaction.type == type_value.value,
            Transaction.status == TransactionStatus.COMPLETED.value,
        ]
        if direction is not None:
            conditions.append(
                Transaction.repayment_direction == direction.value
            )
        return func.coalesce(
            func.sum(case((and_(*conditions), Transaction.amount_inr), else_=0)),
            0,
        )

    row = db.execute(
        select(
            _sum(TransactionType.INCOME).label("income"),
            _sum(TransactionType.EXPENSE).label("expense"),
            _sum(TransactionType.SAVINGS).label("savings"),
            _sum(TransactionType.LENDING).label("lending"),
            _sum(TransactionType.BORROWING).label("borrowing"),
            _sum(
                TransactionType.REPAYMENT, RepaymentDirection.RECEIVED
            ).label("repayment_received"),
            _sum(
                TransactionType.REPAYMENT, RepaymentDirection.PAID
            ).label("repayment_paid"),
        ).where(Transaction.user_id == user_id)
    ).one()
    return {key: Decimal(value or 0) for key, value in row._mapping.items()}


def sum_by_type(
    db: Session,
    user_id: int,
    type_value: TransactionType,
    *,
    date_from: date | None = None,
    date_to: date | None = None,
) -> Decimal:
    stmt = select(
        func.coalesce(func.sum(Transaction.amount_inr), 0)
    ).where(
        Transaction.user_id == user_id,
        Transaction.type == type_value.value,
        Transaction.status == TransactionStatus.COMPLETED.value,
    )
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    return Decimal(db.scalar(stmt) or 0)


def category_breakdown(
    db: Session,
    user_id: int,
    *,
    date_from: date | None = None,
    date_to: date | None = None,
) -> list[tuple[int | None, str | None, str | None, str | None, Decimal]]:
    stmt = (
        select(
            Transaction.category_id,
            Category.name,
            Category.color_hex,
            Category.icon_key,
            func.coalesce(func.sum(Transaction.amount_inr), 0),
        )
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(
            Transaction.user_id == user_id,
            Transaction.type == TransactionType.EXPENSE.value,
            Transaction.status == TransactionStatus.COMPLETED.value,
        )
        .group_by(
            Transaction.category_id,
            Category.name,
            Category.color_hex,
            Category.icon_key,
        )
        .order_by(func.sum(Transaction.amount_inr).desc())
    )
    if date_from is not None:
        stmt = stmt.where(Transaction.transaction_date >= date_from)
    if date_to is not None:
        stmt = stmt.where(Transaction.transaction_date <= date_to)
    return [
        (category_id, name, color, icon, Decimal(total or 0))
        for category_id, name, color, icon, total in db.execute(stmt).all()
    ]


def daily_totals(
    db: Session,
    user_id: int,
    *,
    date_from: date,
    date_to: date,
) -> list[tuple[date, str, str | None, Decimal, int]]:
    rows = db.execute(
        select(
            Transaction.transaction_date,
            Transaction.type,
            Transaction.repayment_direction,
            func.coalesce(func.sum(Transaction.amount_inr), 0),
            func.count(Transaction.id),
        )
        .where(
            Transaction.user_id == user_id,
            Transaction.status == TransactionStatus.COMPLETED.value,
            Transaction.transaction_date >= date_from,
            Transaction.transaction_date <= date_to,
        )
        .group_by(
            Transaction.transaction_date,
            Transaction.type,
            Transaction.repayment_direction,
        )
        .order_by(Transaction.transaction_date.asc())
    ).all()
    return [
        (day, type_value, direction, Decimal(total or 0), int(count))
        for day, type_value, direction, total, count in rows
    ]


def for_range(
    db: Session,
    user_id: int,
    *,
    date_from: date,
    date_to: date,
    limit: int = 2000,
) -> list[Transaction]:
    return list(
        db.scalars(
            select(Transaction)
            .where(
                Transaction.user_id == user_id,
                Transaction.transaction_date >= date_from,
                Transaction.transaction_date <= date_to,
            )
            .order_by(
                Transaction.transaction_date.asc(), Transaction.id.asc()
            )
            .limit(limit)
        )
    )


def count_for_person(db: Session, user_id: int, person_id: int) -> int:
    return int(
        db.scalar(
            select(func.count(Transaction.id)).where(
                Transaction.user_id == user_id,
                Transaction.person_id == person_id,
            )
        )
        or 0
    )
