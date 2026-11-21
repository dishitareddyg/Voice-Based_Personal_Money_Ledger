"""Support tables that replace the former document-store collections.

Revision ID: 0003_support_tables
Revises: 0002_dbms_layer
Create Date: 2026-11-20

Adds ``VOICE_COMMAND``, ``AUDIT_LOG``, ``APPLICATION_EVENT`` and
``EXCHANGE_RATE_CACHE``. The migration is purely additive: it creates four new
tables and never alters or drops an existing financial table or row.

Variable payloads (audit/event payloads and NLP extraction metadata) are JSON
columns; frequently filtered fields are relational columns.

Table names are upper case on purpose (they are part of the specification).
On Linux MySQL (``lower_case_table_names=0``) they are case-sensitive, so
always refer to them exactly as written.

``downgrade`` drops only these four tables. Anything stored in them (audit
history, voice metadata) is lost on downgrade; take a backup first.
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mysql

from alembic import op

revision: str = "0003_support_tables"
down_revision: str | None = "0002_dbms_layer"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TABLE_OPTIONS = {
    "mysql_engine": "InnoDB",
    "mysql_charset": "utf8mb4",
    "mysql_collate": "utf8mb4_0900_ai_ci",
}


def _ts(name: str) -> sa.Column:
    return sa.Column(name, mysql.DATETIME(fsp=6), nullable=False)


def _event_table(name: str, prefix: str) -> None:
    op.create_table(
        name,
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=True),
        sa.Column("request_id", sa.String(length=128), nullable=True),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=True),
        _ts("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=f"fk_{prefix}_user",
            ondelete="SET NULL",
        ),
        sa.CheckConstraint(
            "CHAR_LENGTH(TRIM(event_type)) > 0",
            name=f"ck_{prefix}_event_type",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        f"ix_{prefix}_user_created", name, ["user_id", "created_at"]
    )
    op.create_index(f"ix_{prefix}_request", name, ["request_id"])
    op.create_index(
        f"ix_{prefix}_event_created", name, ["event_type", "created_at"]
    )


def upgrade() -> None:
    op.create_table(
        "VOICE_COMMAND",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=False),
        sa.Column("voice_text", sa.Text(), nullable=False),
        sa.Column("parser_confidence", sa.Double(), nullable=True),
        sa.Column("transaction_id", sa.BigInteger(), nullable=True),
        sa.Column("nlp", sa.JSON(), nullable=False),
        sa.Column(
            "source",
            sa.String(length=64),
            nullable=False,
            server_default="android_speech_recognizer",
        ),
        _ts("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "request_id", name="uq_voice_command_user_request"
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
        sa.CheckConstraint(
            "parser_confidence IS NULL "
            "OR (parser_confidence >= 0 AND parser_confidence <= 1)",
            name="ck_voice_command_confidence",
        ),
        sa.CheckConstraint(
            "CHAR_LENGTH(request_id) >= 8",
            name="ck_voice_command_request_id_length",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_voice_command_user_created",
        "VOICE_COMMAND",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_voice_command_transaction", "VOICE_COMMAND", ["transaction_id"]
    )

    _event_table("AUDIT_LOG", "audit_log")
    _event_table("APPLICATION_EVENT", "application_event")

    op.create_table(
        "EXCHANGE_RATE_CACHE",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("base_currency", sa.String(length=3), nullable=False),
        sa.Column("target_currency", sa.String(length=3), nullable=False),
        sa.Column("rate", sa.Numeric(28, 12), nullable=False),
        sa.Column("provider", sa.String(length=255), nullable=False),
        _ts("retrieved_at"),
        _ts("valid_until"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "base_currency",
            "target_currency",
            name="uq_exchange_rate_cache_pair",
        ),
        sa.CheckConstraint("rate > 0", name="ck_exchange_rate_cache_rate"),
        sa.CheckConstraint(
            "CHAR_LENGTH(base_currency) = 3 "
            "AND CHAR_LENGTH(target_currency) = 3",
            name="ck_exchange_rate_cache_currency",
        ),
        sa.CheckConstraint(
            "valid_until >= retrieved_at",
            name="ck_exchange_rate_cache_validity",
        ),
        **_TABLE_OPTIONS,
    )
    op.create_index(
        "ix_exchange_rate_cache_valid_until",
        "EXCHANGE_RATE_CACHE",
        ["valid_until"],
    )


def downgrade() -> None:
    # Child-less tables: no ordering constraints between these four.
    op.drop_table("EXCHANGE_RATE_CACHE")
    op.drop_table("APPLICATION_EVENT")
    op.drop_table("AUDIT_LOG")
    op.drop_table("VOICE_COMMAND")
