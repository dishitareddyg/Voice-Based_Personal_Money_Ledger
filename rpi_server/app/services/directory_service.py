from __future__ import annotations

from decimal import Decimal

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.enums import ErrorCode, LoanKind
from app.core.errors import AppError
from app.models.category import Category
from app.models.person import Person
from app.repositories import category_repository, person_repository
from app.schemas.category import (
    CategoryCreate,
    CategoryOut,
    CategoryUpdate,
)
from app.schemas.person import PersonCreate, PersonOut, PersonUpdate

_UNCATEGORISED = "Uncategorised"


def person_out(
    person: Person,
    *,
    lent: Decimal = Decimal("0"),
    borrowed: Decimal = Decimal("0"),
) -> PersonOut:
    return PersonOut(
        id=person.id,
        name=person.name,
        phone=person.phone,
        email=person.email,
        notes=person.notes,
        outstanding_lent=float(lent),
        outstanding_borrowed=float(borrowed),
        created_at=person.created_at,
    )


def category_out(
    category: Category,
    *,
    transaction_count: int = 0,
    total_amount: Decimal = Decimal("0"),
) -> CategoryOut:
    return CategoryOut(
        id=category.id,
        name=category.name,
        type=category.type,
        color_hex=category.color_hex,
        icon_key=category.icon_key,
        is_default=category.is_default,
        transaction_count=transaction_count,
        total_amount=float(total_amount),
        created_at=category.created_at,
    )


def list_persons(
    db: Session, user_id: int, *, search: str | None = None
) -> list[PersonOut]:
    people = person_repository.list_all(db, user_id, search=search)
    totals = person_repository.outstanding_totals(db, user_id)
    return [
        person_out(
            person,
            lent=totals.get(person.id, (Decimal("0"), Decimal("0")))[0],
            borrowed=totals.get(person.id, (Decimal("0"), Decimal("0")))[1],
        )
        for person in people
    ]


def create_person(
    db: Session, user_id: int, payload: PersonCreate
) -> PersonOut:
    if person_repository.get_by_name(db, user_id, payload.name):
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "A person with this name already exists.",
            status_code=409,
        )
    person = person_repository.create(
        db,
        user_id=user_id,
        name=payload.name,
        phone=payload.phone,
        email=payload.email,
        notes=payload.notes,
    )
    _commit(db, "A person with this name already exists.")
    return person_out(person)


def update_person(
    db: Session,
    user_id: int,
    person_id: int,
    payload: PersonUpdate,
) -> PersonOut:
    person = _require_person(db, user_id, person_id)
    if payload.name is not None:
        duplicate = person_repository.get_by_name(
            db, user_id, payload.name
        )
        if duplicate is not None and duplicate.id != person.id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "A person with this name already exists.",
                status_code=409,
            )
    person_repository.update(
        db,
        person,
        name=payload.name,
        phone=payload.phone,
        email=payload.email,
        notes=payload.notes,
    )
    _commit(db, "A person with this name already exists.")
    return person_out(
        person,
        lent=person_repository.outstanding_for_person(
            db, user_id, person.id, LoanKind.LENT
        ),
        borrowed=person_repository.outstanding_for_person(
            db, user_id, person.id, LoanKind.BORROWED
        ),
    )


def delete_person(db: Session, user_id: int, person_id: int) -> None:
    person = _require_person(db, user_id, person_id)
    if person_repository.has_transactions(db, user_id, person_id):
        raise AppError(
            ErrorCode.PERSON_IN_USE,
            "This person has transactions and cannot be deleted.",
            status_code=409,
        )
    person_repository.delete(db, person)
    db.commit()


def list_categories(
    db: Session, user_id: int, *, type_value: str | None = None
) -> list[CategoryOut]:
    categories = category_repository.list_all(
        db, user_id, type_value=type_value
    )
    stats = category_repository.stats(db, user_id)
    result: list[CategoryOut] = []
    for category in categories:
        count, total = stats.get(category.id, (0, Decimal("0")))
        result.append(
            category_out(
                category, transaction_count=count, total_amount=total
            )
        )
    return result


def create_category(
    db: Session, user_id: int, payload: CategoryCreate
) -> CategoryOut:
    if category_repository.get_by_name(
        db, user_id, payload.name, payload.type.value
    ):
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "This category already exists for that transaction type.",
            status_code=409,
        )
    category = category_repository.create(
        db,
        user_id=user_id,
        name=payload.name,
        type_value=payload.type.value,
        color_hex=payload.color_hex,
        icon_key=payload.icon,
    )
    _commit(db, "This category already exists for that transaction type.")
    return category_out(category)


def update_category(
    db: Session,
    user_id: int,
    category_id: int,
    payload: CategoryUpdate,
) -> CategoryOut:
    category = _require_category(db, user_id, category_id)
    if payload.name is not None:
        duplicate = category_repository.get_by_name(
            db, user_id, payload.name, category.type
        )
        if duplicate is not None and duplicate.id != category.id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "This category already exists for that transaction type.",
                status_code=409,
            )
    category_repository.update(
        db,
        category,
        name=payload.name,
        color_hex=payload.color_hex,
        icon_key=payload.icon,
    )
    _commit(db, "This category already exists for that transaction type.")
    return category_out(category)


def delete_category(
    db: Session, user_id: int, category_id: int
) -> None:
    category = _require_category(db, user_id, category_id)
    if category_repository.has_transactions(db, user_id, category_id):
        raise AppError(
            ErrorCode.CATEGORY_IN_USE,
            "This category is used by transactions and cannot be deleted.",
            status_code=409,
        )
    category_repository.delete(db, category)
    db.commit()


def ensure_person(
    db: Session,
    user_id: int,
    *,
    person_id: int | None,
    person_name: str | None,
) -> Person:
    if person_id is not None:
        person = person_repository.get(db, user_id, person_id)
        if person is None:
            raise AppError(
                ErrorCode.INVALID_PERSON,
                "The selected person does not exist.",
                status_code=422,
            )
        return person
    if not person_name or not person_name.strip():
        raise AppError(
            ErrorCode.INVALID_PERSON,
            "This transaction needs a person.",
            status_code=422,
        )
    existing = person_repository.get_by_name(db, user_id, person_name)
    if existing is not None:
        return existing
    try:
        with db.begin_nested():
            return person_repository.create(
                db, user_id=user_id, name=person_name
            )
    except IntegrityError:
        existing = person_repository.get_by_name(db, user_id, person_name)
        if existing is None:
            raise AppError(
                ErrorCode.DATABASE_ERROR,
                "Could not save the person. Please try again.",
                status_code=500,
            )
        return existing


def ensure_category(
    db: Session,
    user_id: int,
    *,
    category_id: int | None,
    category_name: str | None,
    type_value: str,
) -> Category | None:
    if category_id is not None:
        category = category_repository.get(db, user_id, category_id)
        if category is None:
            raise AppError(
                ErrorCode.INVALID_CATEGORY,
                "The selected category does not exist.",
                status_code=422,
            )
        return category
    if not category_name or not category_name.strip():
        return None
    existing = category_repository.get_by_name(
        db, user_id, category_name, type_value
    )
    if existing is not None:
        return existing
    try:
        with db.begin_nested():
            return category_repository.create(
                db,
                user_id=user_id,
                name=category_name,
                type_value=type_value,
            )
    except IntegrityError:
        existing = category_repository.get_by_name(
            db, user_id, category_name, type_value
        )
        if existing is None:
            raise AppError(
                ErrorCode.DATABASE_ERROR,
                "Could not save the category. Please try again.",
                status_code=500,
            )
        return existing


def _require_person(db: Session, user_id: int, person_id: int) -> Person:
    person = person_repository.get(db, user_id, person_id)
    if person is None:
        raise AppError(
            ErrorCode.INVALID_PERSON,
            "Person not found.",
            status_code=404,
        )
    return person


def _require_category(
    db: Session, user_id: int, category_id: int
) -> Category:
    category = category_repository.get(db, user_id, category_id)
    if category is None:
        raise AppError(
            ErrorCode.INVALID_CATEGORY,
            "Category not found.",
            status_code=404,
        )
    return category


def _commit(db: Session, conflict_message: str) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            conflict_message,
            status_code=409,
        ) from exc
