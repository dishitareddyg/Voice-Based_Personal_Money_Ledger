"""DBMS layer: checks, interest compounding, indexes and reporting views.

Revision ID: 0002_dbms_layer
Revises: 0001_initial
Create Date: 2026-10-20

Design note: ``income``, ``expenses`` and ``savings`` are read-only typed
views over the central ``transactions`` ledger. They give evaluators simple
relations to query without duplicating financial facts (which would introduce
update anomalies and violate 3NF).
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0002_dbms_layer"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TYPED_VIEWS = (
    "income",
    "expenses",
    "savings",
)

_REPORT_VIEWS = (
    "v_user_balances",
    "v_open_loans",
)

_USER_BALANCES_VIEW = """
CREATE OR REPLACE VIEW v_user_balances AS
SELECT
  user_id,
  SUM(CASE WHEN type = 'income'     THEN amount_inr ELSE 0 END)
    AS total_income,
  SUM(CASE WHEN type = 'expense'    THEN amount_inr ELSE 0 END)
    AS total_expenses,
  SUM(CASE WHEN type = 'savings'    THEN amount_inr ELSE 0 END)
    AS total_savings,
  SUM(CASE WHEN type = 'lending'    THEN amount_inr ELSE 0 END)
    AS money_lent,
  SUM(CASE WHEN type = 'borrowing'  THEN amount_inr ELSE 0 END)
    AS money_borrowed,
  SUM(CASE WHEN type = 'repayment' AND repayment_direction = 'received'
           THEN amount_inr ELSE 0 END) AS repayments_received,
  SUM(CASE WHEN type = 'repayment' AND repayment_direction = 'paid'
           THEN amount_inr ELSE 0 END) AS repayments_paid,
  SUM(
      CASE WHEN type = 'income'    THEN amount_inr
           WHEN type = 'borrowing' THEN amount_inr
           WHEN type = 'repayment' AND repayment_direction = 'received'
                THEN amount_inr
           ELSE -amount_inr END
  ) AS available_balance
FROM transactions
WHERE status = 'completed'
GROUP BY user_id
"""

_OPEN_LOANS_VIEW = """
CREATE OR REPLACE VIEW v_open_loans AS
SELECT
  l.id,
  l.user_id,
  l.kind,
  p.name AS person_name,
  l.principal_amount_inr,
  l.outstanding_amount_inr,
  l.start_date,
  l.due_date,
  l.status,
  CASE
    WHEN l.due_date IS NOT NULL AND l.due_date < CURDATE() THEN 'overdue'
    WHEN l.due_date IS NOT NULL AND l.due_date <= CURDATE() + INTERVAL 30 DAY
         THEN 'due_soon'
    ELSE 'on_track'
  END AS urgency
FROM loans l
JOIN persons p ON p.id = l.person_id
WHERE l.status = 'open'
"""

_INCOME_VIEW = """
CREATE OR REPLACE VIEW income AS
SELECT
  t.id AS transaction_id,
  t.user_id,
  t.amount_inr,
  t.original_amount,
  t.original_currency,
  t.exchange_rate_to_inr,
  t.transaction_date,
  t.description,
  t.category_id,
  c.name AS category_name,
  t.person_id,
  p.name AS person_name,
  t.request_id,
  t.created_at,
  t.updated_at
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.type = 'income' AND t.status = 'completed'
"""

_EXPENSES_VIEW = """
CREATE OR REPLACE VIEW expenses AS
SELECT
  t.id AS transaction_id,
  t.user_id,
  t.amount_inr,
  t.original_amount,
  t.original_currency,
  t.exchange_rate_to_inr,
  t.transaction_date,
  t.description,
  t.category_id,
  c.name AS category_name,
  t.person_id,
  p.name AS person_name,
  t.request_id,
  t.created_at,
  t.updated_at
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.type = 'expense' AND t.status = 'completed'
"""

_SAVINGS_VIEW = """
CREATE OR REPLACE VIEW savings AS
SELECT
  t.id AS transaction_id,
  t.user_id,
  t.amount_inr,
  t.original_amount,
  t.original_currency,
  t.exchange_rate_to_inr,
  t.transaction_date,
  t.description,
  t.category_id,
  c.name AS category_name,
  t.person_id,
  p.name AS person_name,
  t.request_id,
  t.created_at,
  t.updated_at
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
LEFT JOIN persons p ON p.id = t.person_id
WHERE t.type = 'savings' AND t.status = 'completed'
"""


def upgrade() -> None:
    op.add_column(
        "interest_schemes",
        sa.Column(
            "compounding_frequency",
            sa.String(length=20),
            nullable=False,
            server_default="none",
        ),
    )

    # ---- CHECK constraints -------------------------------------------------
    op.create_check_constraint(
        "ck_users_role", "users", "role IN ('user', 'admin')"
    )
    op.create_check_constraint(
        "ck_users_full_name", "users", "CHAR_LENGTH(TRIM(full_name)) > 0"
    )
    op.create_check_constraint(
        "ck_users_timezone", "users", "CHAR_LENGTH(TRIM(timezone)) > 0"
    )

    op.create_check_constraint(
        "ck_persons_name", "persons", "CHAR_LENGTH(TRIM(name)) > 0"
    )

    op.create_check_constraint(
        "ck_categories_type",
        "categories",
        "type IN ('income', 'expense', 'savings', 'lending', "
        "'borrowing', 'repayment')",
    )
    op.create_check_constraint(
        "ck_categories_name",
        "categories",
        "CHAR_LENGTH(TRIM(name)) > 0",
    )

    op.create_check_constraint(
        "ck_interest_schemes_name",
        "interest_schemes",
        "CHAR_LENGTH(TRIM(name)) > 0",
    )
    op.create_check_constraint(
        "ck_interest_schemes_rate",
        "interest_schemes",
        "rate >= 0 AND rate <= 100",
    )
    op.create_check_constraint(
        "ck_interest_schemes_type",
        "interest_schemes",
        "interest_type IN ('simple', 'compound', 'flat')",
    )
    op.create_check_constraint(
        "ck_interest_schemes_compounding",
        "interest_schemes",
        "compounding_frequency IN "
        "('none', 'daily', 'monthly', 'quarterly', "
        "'half_yearly', 'yearly')",
    )

    op.create_check_constraint(
        "ck_loans_kind", "loans", "kind IN ('lent', 'borrowed')"
    )
    op.create_check_constraint(
        "ck_loans_status", "loans", "status IN ('open', 'closed')"
    )
    op.create_check_constraint(
        "ck_loans_principal_positive",
        "loans",
        "principal_amount_inr > 0",
    )
    op.create_check_constraint(
        "ck_loans_outstanding_nonnegative",
        "loans",
        "outstanding_amount_inr >= 0",
    )
    op.create_check_constraint(
        "ck_loans_interest_rate",
        "loans",
        "interest_rate >= 0 AND interest_rate <= 100",
    )
    op.create_check_constraint(
        "ck_loans_interest_type",
        "loans",
        "interest_type IN ('simple', 'compound', 'flat')",
    )
    op.create_check_constraint(
        "ck_loans_due_after_start",
        "loans",
        "due_date IS NULL OR due_date >= start_date",
    )

    op.create_check_constraint(
        "ck_transactions_type",
        "transactions",
        "type IN ('income', 'expense', 'savings', 'lending', "
        "'borrowing', 'repayment')",
    )
    op.create_check_constraint(
        "ck_transactions_amount_positive",
        "transactions",
        "amount_inr > 0",
    )
    op.create_check_constraint(
        "ck_transactions_original_amount_positive",
        "transactions",
        "original_amount IS NULL OR original_amount > 0",
    )
    op.create_check_constraint(
        "ck_transactions_original_currency",
        "transactions",
        "original_currency IS NULL "
        "OR CHAR_LENGTH(original_currency) = 3",
    )
    op.create_check_constraint(
        "ck_transactions_exchange_rate_positive",
        "transactions",
        "exchange_rate_to_inr IS NULL OR exchange_rate_to_inr > 0",
    )
    op.create_check_constraint(
        "ck_transactions_direction",
        "transactions",
        "repayment_direction IS NULL "
        "OR repayment_direction IN ('received', 'paid')",
    )
    op.create_check_constraint(
        "ck_transactions_interest_rate",
        "transactions",
        "interest_rate IS NULL "
        "OR (interest_rate >= 0 AND interest_rate <= 100)",
    )
    op.create_check_constraint(
        "ck_transactions_status",
        "transactions",
        "status IN ('completed', 'reversed')",
    )
    op.create_check_constraint(
        "ck_transactions_request_id_length",
        "transactions",
        "CHAR_LENGTH(request_id) >= 8",
    )

    op.create_check_constraint(
        "ck_repayments_amount_positive",
        "repayments",
        "amount_inr > 0",
    )
    op.create_check_constraint(
        "ck_repayments_direction",
        "repayments",
        "direction IN ('received', 'paid')",
    )
    op.create_check_constraint(
        "ck_repayments_status",
        "repayments",
        "status IN ('completed', 'reversed')",
    )

    # ---- Indexes -----------------------------------------------------------
    op.create_index(
        "ix_categories_user_type", "categories", ["user_id", "type"]
    )
    op.create_index(
        "ix_transactions_user_date_id",
        "transactions",
        ["user_id", "transaction_date", "id"],
    )
    op.create_index(
        "ix_transactions_user_loan",
        "transactions",
        ["user_id", "loan_id"],
    )
    op.create_index(
        "ix_transactions_request_id", "transactions", ["request_id"]
    )
    op.create_index(
        "ix_loans_user_status", "loans", ["user_id", "status"]
    )
    op.create_index(
        "ix_loans_user_kind_status",
        "loans",
        ["user_id", "kind", "status"],
    )
    op.create_index(
        "ix_repayments_user_date",
        "repayments",
        ["user_id", "payment_date"],
    )
    op.create_index(
        "ix_repayments_loan_date",
        "repayments",
        ["loan_id", "payment_date"],
    )

    # ---- Reporting and typed read-only views ------------------------------
    op.execute(_USER_BALANCES_VIEW)
    op.execute(_OPEN_LOANS_VIEW)
    op.execute(_INCOME_VIEW)
    op.execute(_EXPENSES_VIEW)
    op.execute(_SAVINGS_VIEW)


def downgrade() -> None:
    for view_name in (*_REPORT_VIEWS, *_TYPED_VIEWS):
        op.execute(f"DROP VIEW IF EXISTS {view_name}")

    op.drop_index("ix_repayments_loan_date", table_name="repayments")
    op.drop_index("ix_repayments_user_date", table_name="repayments")
    op.drop_index("ix_loans_user_kind_status", table_name="loans")
    op.drop_index("ix_loans_user_status", table_name="loans")
    op.drop_index(
        "ix_transactions_request_id", table_name="transactions"
    )
    op.drop_index(
        "ix_transactions_user_loan", table_name="transactions"
    )
    op.drop_index(
        "ix_transactions_user_date_id", table_name="transactions"
    )
    op.drop_index("ix_categories_user_type", table_name="categories")

    for name, table in (
        ("ck_repayments_status", "repayments"),
        ("ck_repayments_direction", "repayments"),
        ("ck_repayments_amount_positive", "repayments"),
        ("ck_transactions_request_id_length", "transactions"),
        ("ck_transactions_status", "transactions"),
        ("ck_transactions_interest_rate", "transactions"),
        ("ck_transactions_direction", "transactions"),
        ("ck_transactions_exchange_rate_positive", "transactions"),
        ("ck_transactions_original_currency", "transactions"),
        ("ck_transactions_original_amount_positive", "transactions"),
        ("ck_transactions_amount_positive", "transactions"),
        ("ck_transactions_type", "transactions"),
        ("ck_loans_due_after_start", "loans"),
        ("ck_loans_interest_type", "loans"),
        ("ck_loans_interest_rate", "loans"),
        ("ck_loans_outstanding_nonnegative", "loans"),
        ("ck_loans_principal_positive", "loans"),
        ("ck_loans_status", "loans"),
        ("ck_loans_kind", "loans"),
        ("ck_interest_schemes_compounding", "interest_schemes"),
        ("ck_interest_schemes_type", "interest_schemes"),
        ("ck_interest_schemes_rate", "interest_schemes"),
        ("ck_interest_schemes_name", "interest_schemes"),
        ("ck_categories_name", "categories"),
        ("ck_categories_type", "categories"),
        ("ck_persons_name", "persons"),
        ("ck_users_timezone", "users"),
        ("ck_users_full_name", "users"),
        ("ck_users_role", "users"),
    ):
        op.drop_constraint(name, table, type_="check")

    op.drop_column("interest_schemes", "compounding_frequency")
