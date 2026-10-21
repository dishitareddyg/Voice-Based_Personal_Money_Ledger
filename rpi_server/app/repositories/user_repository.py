from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.models.user import User


def get_by_id(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def get_by_email(db: Session, email: str) -> User | None:
    return db.scalar(
        select(User).where(func.lower(User.email) == email.strip().lower())
    )


def lock_by_id(db: Session, user_id: int) -> User | None:
    return db.scalar(
        select(User).where(User.id == user_id).with_for_update()
    )


def create(
    db: Session,
    *,
    full_name: str,
    email: str,
    password_hash: str,
    role: UserRole = UserRole.USER,
    timezone: str = "Asia/Kolkata",
) -> User:
    user = User(
        full_name=full_name.strip(),
        email=email.strip().lower(),
        password_hash=password_hash,
        role=role.value,
        timezone=timezone,
    )
    db.add(user)
    db.flush()
    return user


def count(db: Session) -> int:
    return int(db.scalar(select(func.count(User.id))) or 0)


def list_all(db: Session) -> list[User]:
    return list(db.scalars(select(User).order_by(User.id.asc())))
