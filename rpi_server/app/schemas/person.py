from __future__ import annotations

from pydantic import EmailStr, Field

from app.schemas.common import APIModel, UtcDateTime


class PersonCreate(APIModel):
    name: str = Field(min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=30)
    email: EmailStr | None = None
    notes: str | None = Field(default=None, max_length=500)


class PersonUpdate(APIModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=30)
    email: EmailStr | None = None
    notes: str | None = Field(default=None, max_length=500)


class PersonOut(APIModel):
    id: int
    name: str
    phone: str | None = None
    email: str | None = None
    notes: str | None = None
    outstanding_lent: float = 0
    outstanding_borrowed: float = 0
    created_at: UtcDateTime | None = None


class PersonListResponse(APIModel):
    success: bool = True
    persons: list[PersonOut]


class PersonResponse(APIModel):
    success: bool = True
    person: PersonOut
