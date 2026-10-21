from __future__ import annotations

from pydantic import Field

from app.core.enums import AdminAction
from app.schemas.common import APIModel, UtcDateTime


class AdminActionRequest(APIModel):
    action: AdminAction
    password: str = Field(min_length=1, max_length=128)
    confirm: bool = False
    parameters: dict[str, object] = Field(default_factory=dict)


class AdminActionResponse(APIModel):
    success: bool = True
    action: AdminAction
    message: str
    completed_at: UtcDateTime
    details: dict[str, object] = Field(default_factory=dict)
