"""The Flutter client depends on these paths and response keys."""

from __future__ import annotations

from fastapi.testclient import TestClient

EXPECTED_PATHS = {
    "/api/v1/auth/register",
    "/api/v1/auth/login",
    "/api/v1/auth/me",
    "/api/v1/auth/logout",
    "/api/v1/dashboard/summary",
    "/api/v1/calendar",
    "/api/v1/transactions",
    "/api/v1/transactions/{transaction_id}",
    "/api/v1/commands",
    "/api/v1/expenses",
    "/api/v1/income",
    "/api/v1/savings",
    "/api/v1/lending",
    "/api/v1/borrowing",
    "/api/v1/repayments",
    "/api/v1/loans",
    "/api/v1/persons",
    "/api/v1/persons/{person_id}",
    "/api/v1/categories",
    "/api/v1/categories/{category_id}",
    "/api/v1/admin/actions",
}


def test_all_client_paths_are_registered(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    assert EXPECTED_PATHS.issubset(set(schema["paths"]))


def test_dashboard_summary_fields(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    properties = set(
        schema["components"]["schemas"]["DashboardSummaryOut"]["properties"]
    )
    assert {
        "available_balance",
        "total_income",
        "total_expenses",
        "total_savings",
        "money_lent",
        "money_borrowed",
        "outstanding_lent",
        "outstanding_borrowed",
        "upcoming_repayment_total",
        "upcoming_repayment_count",
        "recent_transactions",
        "category_breakdown",
        "upcoming_repayments",
        "notes",
        "currency",
    } <= properties


def test_loan_and_repayment_fields(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    loan_fields = set(
        schema["components"]["schemas"]["LoanOut"]["properties"]
    )
    assert {
        "id",
        "kind",
        "person_id",
        "person_name",
        "principal_amount_inr",
        "outstanding_amount_inr",
        "start_date",
        "interest_rate",
        "interest_type",
        "due_date",
        "status",
        "description",
    } <= loan_fields

    repayment_fields = set(
        schema["components"]["schemas"]["RepaymentOut"]["properties"]
    )
    assert {
        "id",
        "loan_id",
        "person_name",
        "amount_inr",
        "payment_date",
        "direction",
        "notes",
        "status",
    } <= repayment_fields


def test_transaction_create_requires_type(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    required = set(
        schema["components"]["schemas"]["TransactionCreate"]["required"]
    )
    assert "type" in required
    typed_required = set(
        schema["components"]["schemas"]["TypedTransactionCreate"]["required"]
    )
    assert "type" not in typed_required


def test_voice_command_contract_fields(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    command = schema["components"]["schemas"]["VoiceCommandCreate"]
    assert {
        "request_id",
        "intent",
        "original_amount",
        "original_currency",
        "transaction_date",
        "description",
        "category",
        "person",
        "voice_text",
        "parser_confidence",
    } <= set(command["properties"])
    assert {"request_id", "intent", "original_amount"} <= set(
        command["required"]
    )
    intents = set(
        schema["components"]["schemas"]["CommandIntent"]["enum"]
    )
    assert {
        "CREATE_INCOME",
        "CREATE_EXPENSE",
        "CREATE_SAVINGS",
        "CREATE_LENDING",
        "CREATE_BORROWING",
        "CREATE_REPAYMENT",
    } <= intents


def test_error_envelope_shape(client: TestClient) -> None:
    response = client.get("/api/v1/dashboard/summary")
    body = response.json()
    assert set(body) >= {"success", "error_code", "message", "request_id"}
