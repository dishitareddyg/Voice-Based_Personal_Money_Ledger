"""Release-gate checks that require live MySQL and MongoDB.

These cover the cases that unit/contract tests cannot prove: real persistence,
database constraints, cross-user isolation, admin password verification and a
non-INR transaction through the live exchange-rate provider.
"""

from __future__ import annotations

import os
import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.core.security import create_access_token
from app.core.time import utc_now
from app.database.mongodb.client import get_mongo_database
from app.database.mysql.session import engine

if os.getenv("RUN_INTEGRATION") != "1":
    pytest.skip(
        "Set RUN_INTEGRATION=1 with live MySQL and MongoDB to run.",
        allow_module_level=True,
    )

pytestmark = pytest.mark.integration


def _register(
    client, prefix: str, password: str = "ReleaseTest@123"
) -> tuple[str, dict, dict]:
    email = f"{prefix}-{uuid.uuid4().hex[:10]}@example.com"
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Release Tester",
            "email": email,
            "password": password,
        },
    )
    assert response.status_code == 201, response.text
    token = response.json()["access_token"]
    return email, response.json(), {"Authorization": f"Bearer {token}"}


def _command(client, headers: dict, body: dict):
    return client.post(
        "/api/v1/commands",
        json=body,
        headers={**headers, "Idempotency-Key": body["request_id"]},
    )


def _fund(client, headers: dict, amount: str = "5000.00") -> dict:
    response = _command(
        client,
        headers,
        {
            "request_id": uuid.uuid4().hex,
            "intent": "CREATE_INCOME",
            "original_amount": amount,
            "original_currency": "INR",
            "description": "Release test funding",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_auth_registration_login_wrong_password_and_expired_jwt(client) -> None:
    email, registration, _ = _register(client, "auth")
    password = "ReleaseTest@123"

    assert "password" not in str(registration).lower()
    assert "argon2" not in str(registration).lower()

    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert login.status_code == 200, login.text
    assert login.json()["access_token"]

    wrong = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "WrongPassword@123"},
    )
    assert wrong.status_code == 401
    assert wrong.json()["error_code"] == "INVALID_CREDENTIALS"

    expired = create_access_token(
        user_id=registration["user"]["id"],
        email=email,
        role="user",
        expires_minutes=-1,
    )
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {expired}"},
    )
    assert response.status_code == 401
    assert response.json()["error_code"] == "UNAUTHORIZED"


def test_user_isolation_search_injection_and_non_admin_guard(client) -> None:
    _, _, alice_headers = _register(client, "alice")
    _, _, bob_headers = _register(client, "bob")
    alice_income = _fund(client, alice_headers)

    transaction_id = alice_income["transaction"]["id"]
    response = client.get(
        f"/api/v1/transactions/{transaction_id}", headers=bob_headers
    )
    assert response.status_code == 404

    bob_statement = client.get(
        "/api/v1/transactions", headers=bob_headers
    ).json()
    assert bob_statement["pagination"]["total"] == 0

    injected = client.get(
        "/api/v1/transactions",
        params={"search": "' OR 1=1 --"},
        headers=bob_headers,
    )
    assert injected.status_code == 200
    assert injected.json()["pagination"]["total"] == 0

    forbidden = client.post(
        "/api/v1/admin/actions",
        json={
            "action": "DATABASE_STATS",
            "password": "ReleaseTest@123",
            "confirm": True,
            "parameters": {},
        },
        headers=bob_headers,
    )
    assert forbidden.status_code == 403
    assert forbidden.json()["error_code"] == "FORBIDDEN"


def test_admin_password_and_explicit_confirmation(client) -> None:
    _, registration, headers = _register(
        client, "admin", password="ReleaseAdmin@123"
    )
    user_id = registration["user"]["id"]
    with engine.begin() as connection:
        connection.execute(
            text("UPDATE users SET role = 'admin' WHERE id = :id"),
            {"id": user_id},
        )

    body = {
        "action": "DATABASE_STATS",
        "password": "ReleaseAdmin@123",
        "confirm": True,
        "parameters": {},
    }

    wrong = client.post(
        "/api/v1/admin/actions",
        json={**body, "password": "incorrect"},
        headers=headers,
    )
    assert wrong.status_code == 403
    assert wrong.json()["error_code"] == "ADMIN_PASSWORD_INVALID"

    unconfirmed = client.post(
        "/api/v1/admin/actions",
        json={**body, "confirm": False},
        headers=headers,
    )
    assert unconfirmed.status_code == 400
    assert unconfirmed.json()["error_code"] == "ADMIN_CONFIRMATION_REQUIRED"

    completed = client.post(
        "/api/v1/admin/actions", json=body, headers=headers
    )
    assert completed.status_code == 200, completed.text
    assert completed.json()["action"] == "DATABASE_STATS"

    audit = get_mongo_database().database["audit_logs"].find_one(
        {"user_id": user_id, "event_type": "admin_action"}
    )
    assert audit is not None
    assert audit["payload"]["action"] == "DATABASE_STATS"


def test_invalid_person_category_and_repayment_are_audited(client) -> None:
    _, _, headers = _register(client, "rules")
    _fund(client, headers)

    request_ids = []

    invalid_person = {
        "request_id": uuid.uuid4().hex,
        "intent": "CREATE_LENDING",
        "original_amount": "100.00",
        "original_currency": "INR",
        "person_id": 2_000_000_000,
    }
    request_ids.append(invalid_person["request_id"])
    response = _command(client, headers, invalid_person)
    assert response.status_code == 422
    assert response.json()["error_code"] == "INVALID_PERSON"

    invalid_category = {
        "request_id": uuid.uuid4().hex,
        "intent": "CREATE_EXPENSE",
        "original_amount": "100.00",
        "original_currency": "INR",
        "category_id": 2_000_000_000,
    }
    request_ids.append(invalid_category["request_id"])
    response = _command(client, headers, invalid_category)
    assert response.status_code == 422
    assert response.json()["error_code"] == "INVALID_CATEGORY"

    invalid_repayment = {
        "request_id": uuid.uuid4().hex,
        "intent": "CREATE_REPAYMENT",
        "original_amount": "100.00",
        "original_currency": "INR",
        "person": "Nobody",
        "repayment_direction": "received",
    }
    request_ids.append(invalid_repayment["request_id"])
    response = _command(client, headers, invalid_repayment)
    assert response.status_code == 422
    assert response.json()["error_code"] == "LOAN_NOT_FOUND"

    audit_count = get_mongo_database().database["audit_logs"].count_documents(
        {
            "event_type": "transaction_rejected",
            "request_id": {"$in": request_ids},
        }
    )
    assert audit_count == 3


def test_password_hash_constraints_and_transaction_atomicity(client) -> None:
    email, registration, headers = _register(client, "db")
    user_id = registration["user"]["id"]
    income = _fund(client, headers)
    request_id = income["transaction"]["request_id"]

    with engine.connect() as connection:
        password_hash = connection.scalar(
            text("SELECT password_hash FROM users WHERE email = :email"),
            {"email": email},
        )
    assert password_hash.startswith("$argon2id$")
    assert password_hash != "ReleaseTest@123"

    now = utc_now().replace(tzinfo=None)
    with pytest.raises(IntegrityError):
        with engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO transactions "
                    "(user_id, type, amount_inr, transaction_date, status, "
                    "request_id, created_at, updated_at) "
                    "VALUES (:user_id, 'expense', 1.00, CURDATE(), "
                    "'completed', :request_id, :now, :now)"
                ),
                {
                    "user_id": 2_000_000_000,
                    "request_id": uuid.uuid4().hex,
                    "now": now,
                },
            )

    with pytest.raises(IntegrityError):
        with engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO transactions "
                    "(user_id, type, amount_inr, transaction_date, status, "
                    "request_id, created_at, updated_at) "
                    "VALUES (:user_id, 'expense', 1.00, CURDATE(), "
                    "'completed', :request_id, :now, :now)"
                ),
                {
                    "user_id": user_id,
                    "request_id": request_id,
                    "now": now,
                },
            )

    statement = client.get("/api/v1/transactions", headers=headers).json()
    assert statement["pagination"]["total"] == 1
    assert statement["items"][0]["request_id"] == request_id


def test_live_currency_conversion_and_mongodb_cache(client) -> None:
    _, registration, headers = _register(client, "fx")
    body = {
        "request_id": uuid.uuid4().hex,
        "intent": "CREATE_INCOME",
        "original_amount": "10.00",
        "original_currency": "USD",
        "description": "USD income",
    }
    response = _command(client, headers, body)
    assert response.status_code == 201, response.text
    payload = response.json()

    assert payload["transaction"]["original_currency"] == "USD"
    assert payload["transaction"]["original_amount"] == "10.00"
    assert float(payload["exchange_rate_to_inr"]) > 0
    assert float(payload["amount_inr"]) > 10

    cache = get_mongo_database().database["exchange_rates"].find_one(
        {
            "base_currency": "USD",
            "target_currency": "INR",
            "valid_until": {"$gt": utc_now()},
        }
    )
    assert cache is not None
    assert cache["rate"].to_decimal() > 0
    assert cache["provider"]
    assert cache["retrieved_at"]
    assert cache["valid_until"]
