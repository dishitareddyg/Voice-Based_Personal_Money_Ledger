"""Supporting MySQL tables for voice metadata, audit, events and FX cache.

All four tables replace the former document collections. Financial tables are
not modified. Existing data can be imported with
``python -m app.scripts.import_legacy_supporting_export`` after exporting the
legacy documents to JSON Lines; see the deployment guide.

Revision ID: 0003_supporting_tables
Revises: 0002_dbms_layer
Create Date: 2026-11-20
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0003_supporting_tables"
down_revision: str | None = "0002_dbms_layer"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TABLE_OPTIONS = {
    "mysql_engine": "InnoDB",
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_0900_ai_ci",
}


def upgrade() -> None:
    op.create_table(
        "AUDIT_LOG",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=True),
        sa.Column("event_type", sa.String(length=120), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_audit_log_user",
            ondelete="SET NULL",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_audit_log_user_created",
        "AUDIT_LOG",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_audit_log_event_created",
        "AUDIT_LOG",
        ["event_type", "created_at"],
    )
    op.create_index(
        "ix_audit_log_request_id", "AUDIT_LOG", ["request_id"]
    )

    op.create_table(
        "APPLICATION_EVENT",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=True),
        sa.Column("event_type", sa.String(length=120), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_application_event_user",
            ondelete="SET NULL",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_application_event_user_created",
        "APPLICATION_EVENT",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_application_event_event_created",
        "APPLICATION_EVENT",
        ["event_type", "created_at"],
    )
    op.create_index(
        "ix_application_event_request_id",
        "APPLICATION_EVENT",
        ["request_id"],
    )

    op.create_table(
        "VOICE_COMMAND",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=False),
        sa.Column("voice_text", sa.Text(), nullable=False),
        sa.Column("parser_confidence", sa.Float(), nullable=True),
        sa.Column("transaction_id", sa.BigInteger(), nullable=True),
        sa.Column("nlp_metadata", sa.JSON(), nullable=True),
        sa.Column(
            "source",
            sa.String(length=64),
            nullable=False,
            server_default="android_speech_recognizer",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "request_id",
            name="uq_voice_command_user_request",
        ),
        sa.CheckConstraint(
            "parser_confidence IS NULL "
            "OR (parser_confidence >= 0 AND parser_confidence <= 1)",
            name="ck_voice_command_confidence",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_voice_command_user",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id"],
            ["transactions.id"],
            name="fk_voice_command_transaction",
            ondelete="SET NULL",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_voice_command_user_created",
        "VOICE_COMMAND",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_voice_command_transaction_id",
        "VOICE_COMMAND",
        ["transaction_id"],
    )

    op.create_table(
        "EXCHANGE_RATE_CACHE",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column(
            "base_currency", sa.String(length=3), nullable=False
        ),
        sa.Column(
            "target_currency", sa.String(length=3), nullable=False
        ),
        sa.Column("rate", sa.Numeric(precision=18, scale=8), nullable=False),
        sa.Column("provider", sa.String(length=255), nullable=False),
        sa.Column("retrieved_at", sa.DateTime(), nullable=False),
        sa.Column("valid_until", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "base_currency",
            "target_currency",
            name="uq_exchange_rate_cache_pair",
        ),
        sa.CheckConstraint(
            "rate > 0", name="ck_exchange_rate_cache_rate_positive"
        ),
        sa.CheckConstraint(
            "CHAR_LENGTH(base_currency) = 3 "
            "AND CHAR_LENGTH(target_currency) = 3",
            name="ck_exchange_rate_cache_currency_length",
        ),
        sa.CheckConstraint(
            "valid_until > retrieved_at",
            name="ck_exchange_rate_cache_validity",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_exchange_rate_cache_pair_retrieved",
        "EXCHANGE_RATE_CACHE",
        ["base_currency", "target_currency", "retrieved_at"],
    )
    op.create_index(
        "ix_exchange_rate_cache_valid_until",
        "EXCHANGE_RATE_CACHE",
        ["valid_until"],
    )


def downgrade() -> None:
    op.drop_table("EXCHANGE_RATE_CACHE")
    op.drop_table("VOICE_COMMAND")
    op.drop_table("APPLICATION_EVENT")
    op.drop_table("AUDIT_LOG")
