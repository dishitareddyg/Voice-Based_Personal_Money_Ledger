from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database.mysql.session import get_db
from app.models.user import User
from app.schemas.person import (
    PersonCreate,
    PersonListResponse,
    PersonResponse,
    PersonUpdate,
)
from app.services import directory_service

router = APIRouter(prefix="/persons", tags=["persons"])


@router.get("", response_model=PersonListResponse)
def list_persons(
    search: str | None = Query(default=None, max_length=120),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PersonListResponse:
    return PersonListResponse(
        persons=directory_service.list_persons(
            db, user.id, search=search
        )
    )


@router.post("", response_model=PersonResponse, status_code=201)
def create_person(
    payload: PersonCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PersonResponse:
    return PersonResponse(
        person=directory_service.create_person(db, user.id, payload)
    )


@router.patch("/{person_id}", response_model=PersonResponse)
def update_person(
    person_id: int,
    payload: PersonUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PersonResponse:
    return PersonResponse(
        person=directory_service.update_person(
            db, user.id, person_id, payload
        )
    )


@router.delete("/{person_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_person(
    person_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Response:
    directory_service.delete_person(db, user.id, person_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
