from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.enums import ErrorCode, TransactionType
from app.core.errors import AppError
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.category import (
    CategoryCreate,
    CategoryListResponse,
    CategoryResponse,
    CategoryUpdate,
)
from app.services import directory_service

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=CategoryListResponse)
def list_categories(
    type_value: str | None = Query(default=None, alias="type"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CategoryListResponse:
    if type_value is not None:
        try:
            TransactionType(type_value)
        except ValueError as exc:
            raise AppError(
                ErrorCode.INVALID_TRANSACTION_TYPE,
                "Unknown transaction type.",
                status_code=422,
            ) from exc
    return CategoryListResponse(
        categories=directory_service.list_categories(
            db, user.id, type_value=type_value
        )
    )


@router.post("", response_model=CategoryResponse, status_code=201)
def create_category(
    payload: CategoryCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CategoryResponse:
    return CategoryResponse(
        category=directory_service.create_category(db, user.id, payload)
    )


@router.patch("/{category_id}", response_model=CategoryResponse)
def update_category(
    category_id: int,
    payload: CategoryUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CategoryResponse:
    return CategoryResponse(
        category=directory_service.update_category(
            db, user.id, category_id, payload
        )
    )


@router.delete(
    "/{category_id}", status_code=status.HTTP_204_NO_CONTENT
)
def delete_category(
    category_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Response:
    directory_service.delete_category(db, user.id, category_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
