"""Integration tests. Skipped unless RUN_INTEGRATION=1 and services exist."""

from __future__ import annotations

import json
import os

import pytest
from sqlalchemy import text

from app.database.mysql.session import engine

if os.getenv("RUN_INTEGRATION") != "1":
    pytest.skip(
        "Set RUN_INTEGRATION=1 with live MySQL 8 to run.",
        allow_module_level=True,
    )

pytestmark = pytest.mark.integration


def _count(conn, table: str, request_id: str) -> int:
    return conn.execute(
        text(f"SELECT COUNT(*) FROM `{table}` WHERE request_id = :r"),
        {"r": request_id},
    ).scalar_one()


def test_full_ledger_flow(client) -> None:
    import uuid

    ready = client.get("/health/ready")
    assert ready.status_code == 200, ready.text
    assert ready.json()["checks"] == {"mysql": "ok"}

    email = f"flow-{uuid.uuid4().hex[:10]}@example.com"
    registration = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Flow Tester",
            "email": email,
            "password": "FlowTester@123",
        },
    )
    assert registration.status_code == 201, registration.text
    token = registration.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    def post(path: str, body: dict):
        response = client.post(path, json=body, headers=headers)
        assert response.status_code == 201, response.text
        return response.json()

    request_id = uuid.uuid4().hex
    voice_text = "I received one thousand rupees"
    income = post(
        "/api/v1/transactions",
        {
            "request_id": request_id,
            "type": "income",
            "amount": "1000.00",
            "currency": "INR",
            "voice_text": voice_text,
            "parser_confidence": 0.97,
        },
    )
    assert income["available_balance"] == "1000.00"

    replay = post(
        "/api/v1/transactions",
        {
            "request_id": income["transaction"]["request_id"],
            "type": "income",
            "amount": "1000.00",
            "currency": "INR",
        },
    )
    assert replay["idempotent_replay"] is True

    expense = post(
        "/api/v1/expenses",
        {
            "request_id": uuid.uuid4().hex,
            "amount": "250.00",
            "currency": "INR",
            "category_name": "Food",
        },
    )
    assert expense["available_balance"] == "750.00"

    blocked = client.post(
        "/api/v1/expenses",
        json={
            "request_id": uuid.uuid4().hex,
            "amount": "10000.00",
            "currency": "INR",
        },
        headers=headers,
    )
    assert blocked.status_code == 422
    assert blocked.json()["error_code"] == "INSUFFICIENT_BALANCE"

    loan = post(
        "/api/v1/lending",
        {
            "request_id": uuid.uuid4().hex,
            "amount": "500.00",
            "currency": "INR",
            "person_name": "Asha",
        },
    )
    assert loan["available_balance"] == "250.00"

    repayment = post(
        "/api/v1/repayments",
        {
            "request_id": uuid.uuid4().hex,
            "amount": "200.00",
            "currency": "INR",
            "person_name": "Asha",
            "repayment_direction": "received",
        },
    )
    assert repayment["available_balance"] == "450.00"

    overpayment = client.post(
        "/api/v1/repayments",
        json={
            "request_id": uuid.uuid4().hex,
            "amount": "400.00",
            "currency": "INR",
            "person_name": "Asha",
            "repayment_direction": "received",
        },
        headers=headers,
    )
    assert overpayment.status_code == 422
    assert overpayment.json()["error_code"] == "REPAYMENT_EXCEEDS_OUTSTANDING"

    admin_users = client.get("/api/v1/admin/users", headers=headers)
    assert admin_users.status_code == 403

    loans = client.get("/api/v1/loans", headers=headers).json()["loans"]
    assert loans[0]["outstanding_amount_inr"] == "300.00"

    summary = client.get(
        "/api/v1/dashboard/summary", headers=headers
    ).json()["summary"]
    assert summary["available_balance"] == 450.0
    assert summary["outstanding_lent"] == 300.0

    statement = client.get(
        "/api/v1/transactions", headers=headers
    ).json()
    assert statement["pagination"]["total"] == 4

    user_id = income["transaction"]["user_id"]
    with engine.connect() as conn:
        voice_rows = conn.execute(
            text(
                "SELECT voice_text, transaction_id FROM VOICE_COMMAND "
                "WHERE user_id = :u AND request_id = :r"
            ),
            {"u": user_id, "r": request_id},
        ).all()
        assert len(voice_rows) == 1
        assert voice_rows[0][0] == voice_text
        assert voice_rows[0][1] == income["transaction"]["id"]
        assert _count(conn, "AUDIT_LOG", request_id) == 1
        assert _count(conn, "APPLICATION_EVENT", request_id) == 1


def test_voice_command_contract_end_to_end(client) -> None:
    """The documented intent payload records one row and audits rejections."""

    import uuid

    ready = client.get("/health/ready")
    assert ready.status_code == 200, ready.text

    email = f"cmd-{uuid.uuid4().hex[:10]}@example.com"
    registration = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Command Tester",
            "email": email,
            "password": "CommandTester@123",
        },
    )
    assert registration.status_code == 201, registration.text
    headers = {
        "Authorization": f"Bearer {registration.json()['access_token']}"
    }

    def command(body: dict):
        return client.post(
            "/api/v1/commands",
            json=body,
            headers={
                **headers,
                "Idempotency-Key": body["request_id"],
            },
        )

    income_id = uuid.uuid4().hex
    income = command(
        {
            "request_id": income_id,
            "intent": "CREATE_INCOME",
            "original_amount": "5000.00",
            "original_currency": "INR",
            "description": "Opening balance",
            "transaction_date": "2026-10-20",
        }
    )
    assert income.status_code == 201, income.text
    assert income.json()["available_balance"] == "5000.00"

    expense_body = {
        "request_id": uuid.uuid4().hex,
        "intent": "CREATE_EXPENSE",
        "original_amount": "2000.00",
        "original_currency": "INR",
        "category": "Groceries",
        "transaction_date": "2026-10-20",
        "description": "Groceries",
        "voice_text": "I spent 2000 rupees on groceries",
        "parser_confidence": 0.97,
    }
    expense = command(expense_body)
    assert expense.status_code == 201, expense.text
    expense_data = expense.json()
    assert expense_data["transaction"]["type"] == "expense"
    assert expense_data["transaction"]["category_name"] == "Groceries"
    assert expense_data["amount_inr"] == "2000.00"
    assert expense_data["available_balance"] == "3000.00"

    replay = command(expense_body)
    assert replay.status_code == 201, replay.text
    assert replay.json()["idempotent_replay"] is True
    assert replay.json()["transaction"]["id"] == expense_data["transaction"]["id"]

    rejected_id = uuid.uuid4().hex
    rejected = command(
        {
            "request_id": rejected_id,
            "intent": "CREATE_EXPENSE",
            "original_amount": "100000.00",
            "original_currency": "INR",
            "category": "Groceries",
            "transaction_date": "2026-10-20",
            "description": "Too expensive",
            "voice_text": "I spent 100000 rupees on groceries",
            "parser_confidence": 0.96,
        }
    )
    assert rejected.status_code == 422, rejected.text
    assert rejected.json()["error_code"] == "INSUFFICIENT_BALANCE"

    statement = client.get("/api/v1/transactions", headers=headers).json()
    assert statement["pagination"]["total"] == 2

    with engine.connect() as conn:
        rejection_audit = conn.execute(
            text(
                "SELECT payload FROM AUDIT_LOG WHERE request_id = :r "
                "AND event_type = 'transaction_rejected'"
            ),
            {"r": rejected_id},
        ).scalar_one()
        rejection_audit = json.loads(rejection_audit)
        assert rejection_audit["error_code"] == "INSUFFICIENT_BALANCE"
        assert rejection_audit["transaction_type"] == "expense"
        nlp = conn.execute(
            text(
                "SELECT nlp FROM VOICE_COMMAND "
                "WHERE user_id = :u AND request_id = :r"
            ),
            {
                "u": expense_data["transaction"]["user_id"],
                "r": expense_body["request_id"],
            },
        ).all()
        assert len(nlp) == 1
        assert json.loads(nlp[0][0])["intent"] == "expense"
