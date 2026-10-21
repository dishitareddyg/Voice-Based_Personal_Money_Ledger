from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.deps import (
    client_metadata,
    enforce_idempotency_header,
    get_current_user,
)
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.transaction import TransactionCreateResponse, VoiceCommandCreate
from app.services import transaction_service

router = APIRouter(prefix="/commands", tags=["voice-commands"])


@router.post("", response_model=TransactionCreateResponse, status_code=201)
def create_voice_command(
    payload: VoiceCommandCreate,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TransactionCreateResponse:
    """Execute one confirmed, structured voice command.

    The intent is mapped to the same server-authoritative transaction service
    used by the typed endpoints, so balances, currencies, loans and idempotency
    behave identically regardless of which client path is used.
    """

    enforce_idempotency_header(request, payload.request_id)
    ip_address, user_agent = client_metadata(request)
    return transaction_service.create_transaction(
        db,
        user,
        payload.to_transaction_payload(),
        transaction_type=payload.intent.transaction_type,
        ip_address=ip_address,
        user_agent=user_agent,
    )
