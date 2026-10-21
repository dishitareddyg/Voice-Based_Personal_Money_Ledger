from __future__ import annotations

from pydantic import EmailStr, Field

from app.schemas.common import APIModel, UtcDateTime


class RegisterRequest(APIModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    timezone: str = Field(default="Asia/Kolkata", max_length=64)


class LoginRequest(APIModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(APIModel):
    id: int
    full_name: str
    email: EmailStr
    role: str
    is_active: bool
    timezone: str
    created_at: UtcDateTime


class AuthResponse(APIModel):
    success: bool = True
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class MeResponse(APIModel):
    success: bool = True
    user: UserOut


class MessageResponse(APIModel):
    success: bool = True
    message: str
