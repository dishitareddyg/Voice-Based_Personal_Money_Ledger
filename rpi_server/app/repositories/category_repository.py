from __future__ import annotations

from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.transaction import Transaction


def get(
    db: Session, user_id: int, category_id: int
) -> Category | None:
    return db.scalar(
        select(Category).where(
            Category.id == category_id, Category.user_id == user_id
        )
    )


def get_by_name(
    db: Session, user_id: int, name: str, type_value: str
) -> Category | None:
    return db.scalar(
        select(Category).where(
            Category.user_id == user_id,
            Category.type == type_value,
            func.lower(Category.name) == name.strip().lower(),
        )
    )


def list_all(
    db: Session, user_id: int, *, type_value: str | None = None
) -> list[Category]:
    stmt = select(Category).where(Category.user_id == user_id)
    if type_value is not None:
        stmt = stmt.where(Category.type == type_value)
    return list(db.scalars(stmt.order_by(Category.name.asc())))


def create(
    db: Session,
    *,
    user_id: int,
    name: str,
    type_value: str,
    color_hex: str = "#0E6B5C",
    icon_key: str = "category",
    is_default: bool = False,
) -> Category:
    category = Category(
        user_id=user_id,
        name=name.strip(),
        type=type_value,
        color_hex=color_hex,
        icon_key=icon_key,
        is_default=is_default,
    )
    db.add(category)
    db.flush()
    return category


def update(db: Session, category: Category, **values: object) -> Category:
    for field, value in values.items():
        if value is not None:
            setattr(category, field, value)
    db.flush()
    return category


def delete(db: Session, category: Category) -> None:
    db.delete(category)
    db.flush()


def has_transactions(
    db: Session, user_id: int, category_id: int
) -> bool:
    return bool(
        db.scalar(
            select(func.count(Transaction.id))
            .where(
                Transaction.user_id == user_id,
                Transaction.category_id == category_id,
            )
            .limit(1)
        )
    )


def stats(
    db: Session, user_id: int
) -> dict[int, tuple[int, Decimal]]:
    """category_id -> (transaction_count, total_amount)."""
    rows = db.execute(
        select(
            Transaction.category_id,
            func.count(Transaction.id),
            func.coalesce(func.sum(Transaction.amount_inr), 0),
        )
        .where(
            Transaction.user_id == user_id,
            Transaction.category_id.is_not(None),
        )
        .group_by(Transaction.category_id)
    ).all()
    return {
        int(category_id): (int(count), Decimal(total))
        for category_id, count, total in rows
    }
