"""Initial Voice Ledger schema (MySQL 8.x).

The loans.source_transaction_id <-> transactions.loan_id pair is circular, so the
loans table is created without that foreign key and the constraint is added
after transactions exists.

Revision ID: 0001_initial
Revises:
Create Date: 2026-01-01
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TABLE_OPTIONS = {
    "mysql_engine": "InnoDB",
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_0900_ai_ci",
}


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "role", sa.String(length=20), nullable=False, server_default="user"
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("1"),
        ),
        sa.Column(
            "timezone",
            sa.String(length=64),
            nullable=False,
            server_default="Asia/Kolkata",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        **_TABLE_OPTIONS,
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "persons",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=30), nullable=True),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("notes", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_persons_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "name", name="uq_persons_user_name"),
        **_TABLE_OPTIONS,
    )
    op.create_index("ix_persons_user_id", "persons", ["user_id"])

    op.create_table(
        "categories",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column(
            "color_hex", sa.String(length=9), nullable=False,
            server_default="#0E6B5C",
        ),
        sa.Column(
            "icon_key", sa.String(length=40), nullable=False,
            server_default="category",
        ),
        sa.Column(
            "is_default",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_categories_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "name", "type", name="uq_categories_user_name_type"
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index("ix_categories_user_id", "categories", ["user_id"])
    op.create_index("ix_categories_type", "categories", ["type"])

    op.create_table(
        "interest_schemes",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("rate", sa.Numeric(precision=6, scale=3), nullable=False),
        sa.Column(
            "interest_type",
            sa.String(length=20),
            nullable=False,
            server_default="simple",
        ),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("1"),
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_interest_schemes_user",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "name", name="uq_interest_schemes_user_name"
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_interest_schemes_user_id", "interest_schemes", ["user_id"]
    )

    op.create_table(
        "loans",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("person_id", sa.BigInteger(), nullable=False),
        sa.Column("source_transaction_id", sa.BigInteger(), nullable=True),
        sa.Column("kind", sa.String(length=10), nullable=False),
        sa.Column(
            "principal_amount_inr",
            sa.Numeric(precision=15, scale=2),
            nullable=False,
        ),
        sa.Column(
            "outstanding_amount_inr",
            sa.Numeric(precision=15, scale=2),
            nullable=False,
        ),
        sa.Column(
            "interest_rate",
            sa.Numeric(precision=6, scale=3),
            nullable=False,
            server_default="0.000",
        ),
        sa.Column(
            "interest_type",
            sa.String(length=20),
            nullable=False,
            server_default="simple",
        ),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="open",
        ),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_loans_user",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["person_id"],
            ["persons.id"],
            name="fk_loans_person",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "source_transaction_id", name="uq_loans_source_transaction"
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index("ix_loans_user_id", "loans", ["user_id"])
    op.create_index("ix_loans_person_id", "loans", ["person_id"])
    op.create_index("ix_loans_kind", "loans", ["kind"])
    op.create_index("ix_loans_status", "loans", ["status"])

    op.create_table(
        "transactions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column(
            "amount_inr", sa.Numeric(precision=15, scale=2), nullable=False
        ),
        sa.Column(
            "original_amount",
            sa.Numeric(precision=15, scale=2),
            nullable=True,
        ),
        sa.Column("original_currency", sa.String(length=3), nullable=True),
        sa.Column(
            "exchange_rate_to_inr",
            sa.Numeric(precision=18, scale=8),
            nullable=True,
        ),
        sa.Column("transaction_date", sa.Date(), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.Column("category_id", sa.BigInteger(), nullable=True),
        sa.Column("person_id", sa.BigInteger(), nullable=True),
        sa.Column("loan_id", sa.BigInteger(), nullable=True),
        sa.Column("repayment_direction", sa.String(length=10), nullable=True),
        sa.Column(
            "interest_rate", sa.Numeric(precision=6, scale=3), nullable=True
        ),
        sa.Column("interest_type", sa.String(length=20), nullable=True),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="completed",
        ),
        sa.Column("request_id", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_transactions_user",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["categories.id"],
            name="fk_transactions_category",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["person_id"],
            ["persons.id"],
            name="fk_transactions_person",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["loan_id"],
            ["loans.id"],
            name="fk_transactions_loan",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "request_id", name="uq_transactions_user_request"
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index("ix_transactions_user_id", "transactions", ["user_id"])
    op.create_index("ix_transactions_type", "transactions", ["type"])
    op.create_index(
        "ix_transactions_transaction_date",
        "transactions",
        ["transaction_date"],
    )
    op.create_index(
        "ix_transactions_category_id", "transactions", ["category_id"]
    )
    op.create_index(
        "ix_transactions_person_id", "transactions", ["person_id"]
    )
    op.create_index("ix_transactions_loan_id", "transactions", ["loan_id"])
    op.create_index(
        "ix_transactions_user_date",
        "transactions",
        ["user_id", "transaction_date"],
    )
    op.create_index(
        "ix_transactions_user_type", "transactions", ["user_id", "type"]
    )
    op.create_index(
        "ix_transactions_user_category",
        "transactions",
        ["user_id", "category_id"],
    )
    op.create_index(
        "ix_transactions_user_person",
        "transactions",
        ["user_id", "person_id"],
    )

    op.create_foreign_key(
        "fk_loans_source_transaction",
        "loans",
        "transactions",
        ["source_transaction_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "repayments",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("loan_id", sa.BigInteger(), nullable=False),
        sa.Column("transaction_id", sa.BigInteger(), nullable=False),
        sa.Column("person_id", sa.BigInteger(), nullable=False),
        sa.Column(
            "amount_inr", sa.Numeric(precision=15, scale=2), nullable=False
        ),
        sa.Column("direction", sa.String(length=10), nullable=False),
        sa.Column("payment_date", sa.Date(), nullable=False),
        sa.Column("notes", sa.String(length=255), nullable=True),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="completed",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_repayments_user",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["loan_id"],
            ["loans.id"],
            name="fk_repayments_loan",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id"],
            ["transactions.id"],
            name="fk_repayments_transaction",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["person_id"],
            ["persons.id"],
            name="fk_repayments_person",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "transaction_id", name="uq_repayments_transaction"
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index("ix_repayments_user_id", "repayments", ["user_id"])
    op.create_index("ix_repayments_loan_id", "repayments", ["loan_id"])
    op.create_index("ix_repayments_person_id", "repayments", ["person_id"])


def downgrade() -> None:
    op.drop_table("repayments")
    op.drop_constraint(
        "fk_loans_source_transaction", "loans", type_="foreignkey"
    )
    op.drop_table("transactions")
    op.drop_table("loans")
    op.drop_table("interest_schemes")
    op.drop_table("categories")
    op.drop_table("persons")
    op.drop_table("users")
