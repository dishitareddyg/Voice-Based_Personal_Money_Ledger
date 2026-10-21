from __future__ import annotations

from pydantic import Field

from app.core.enums import TransactionType
from app.schemas.common import APIModel, UtcDateTime


class CategoryCreate(APIModel):
    name: str = Field(min_length=1, max_length=80)
    type: TransactionType
    color_hex: str = Field(default="#0E6B5C", pattern=r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")
    icon: str = Field(default="category", max_length=40)


class CategoryUpdate(APIModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    color_hex: str | None = Field(
        default=None, pattern=r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"
    )
    icon: str | None = Field(default=None, max_length=40)


class CategoryOut(APIModel):
    id: int
    name: str
    type: TransactionType
    color_hex: str
    icon_key: str
    is_default: bool = False
    transaction_count: int = 0
    total_amount: float = 0
    created_at: UtcDateTime | None = None


class CategoryListResponse(APIModel):
    success: bool = True
    categories: list[CategoryOut]


class CategoryResponse(APIModel):
    success: bool = True
    category: CategoryOut
