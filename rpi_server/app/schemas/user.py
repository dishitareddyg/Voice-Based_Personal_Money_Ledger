from __future__ import annotations

from pydantic import Field

from app.schemas.auth import UserOut
from app.schemas.common import APIModel


class UserUpdateRequest(APIModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    timezone: str | None = Field(default=None, max_length=64)


class PasswordChangeRequest(APIModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class UserListResponse(APIModel):
    success: bool = True
    users: list[UserOut]


class UserResponse(APIModel):
    success: bool = True
    user: UserOut
