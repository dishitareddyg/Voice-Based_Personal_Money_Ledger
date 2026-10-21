from __future__ import annotations

from pathlib import Path

import sqlglot
from sqlglot import exp
from sqlglot.optimizer.qualify import qualify

from app.database.mongodb.client import COLLECTIONS
from app.scripts.seed_demo import _CATEGORIES, _PERSONS

SERVER_ROOT = Path(__file__).resolve().parents[1]
SQL_ROOT = SERVER_ROOT / "sql"
REPO_ROOT = SERVER_ROOT.parent


def test_all_sql_files_parse_as_mysql() -> None:
    for path in sorted(SQL_ROOT.rglob("*.sql")):
        statements = sqlglot.parse(
            path.read_text(encoding="utf-8"), read="mysql"
        )
        assert statements, f"{path} contains no SQL statements"


def test_demo_queries_resolve_against_reference_schema() -> None:
    schema: dict[str, dict[str, str]] = {}
    schema_sql = (SQL_ROOT / "schema" / "001_schema.sql").read_text(
        encoding="utf-8"
    )
    for statement in sqlglot.parse(schema_sql, read="mysql"):
        if isinstance(statement, exp.Create) and statement.kind == "TABLE":
            table = statement.this.this.name
            schema[table] = {
                column.name: "TEXT"
                for column in statement.this.expressions
                if isinstance(column, exp.ColumnDef)
            }

    views_sql = (SQL_ROOT / "schema" / "002_views.sql").read_text(
        encoding="utf-8"
    )
    for statement in sqlglot.parse(views_sql, read="mysql"):
        if isinstance(statement, exp.Create) and statement.kind == "VIEW":
            name = statement.this.this.name
            qualified = qualify(
                statement.expression.copy(),
                schema=schema,
                dialect="mysql",
            )
            schema[name] = dict.fromkeys(qualified.named_selects, "TEXT")

    for path in sorted((SQL_ROOT / "demo_queries").glob("*.sql")):
        for statement in sqlglot.parse(
            path.read_text(encoding="utf-8"), read="mysql"
        ):
            if isinstance(statement, exp.Query):
                qualify(
                    statement.copy(),
                    schema=schema,
                    dialect="mysql",
                    validate_qualify_columns=True,
                )


def test_twelve_demo_query_files_exist() -> None:
    files = sorted((SQL_ROOT / "demo_queries").glob("*.sql"))
    assert len(files) == 12
    assert [path.name[:2] for path in files] == [
        f"{number:02d}"
        for number in range(1, 13)
    ]
    for path in files:
        text = path.read_text(encoding="utf-8")
        assert "USE voice_ledger;" in text
        assert "SELECT" in text.upper()


def test_reference_schema_has_integrity_objects() -> None:
    schema = (SQL_ROOT / "schema" / "001_schema.sql").read_text(
        encoding="utf-8"
    )
    for table in (
        "users",
        "persons",
        "categories",
        "interest_schemes",
        "loans",
        "transactions",
        "repayments",
    ):
        assert f"CREATE TABLE IF NOT EXISTS {table}" in schema
    for constraint in (
        "ck_users_role",
        "ck_categories_type",
        "ck_interest_schemes_compounding",
        "ck_loans_outstanding_nonnegative",
        "ck_transactions_amount_positive",
        "ck_repayments_direction",
    ):
        assert constraint in schema
    assert "uq_transactions_user_request" in schema
    assert "ix_transactions_user_date_id" in schema
    assert "fk_loans_source_transaction" in schema


def test_views_include_typed_relations_without_subtype_tables() -> None:
    views = (SQL_ROOT / "schema" / "002_views.sql").read_text(
        encoding="utf-8"
    )
    schema = (SQL_ROOT / "schema" / "001_schema.sql").read_text(
        encoding="utf-8"
    )
    assert "SET NAMES utf8mb4;" in views
    for view in ("v_user_balances", "v_open_loans", "income", "expenses",
                 "savings"):
        assert f"CREATE OR REPLACE VIEW {view}" in views
    assert "CREATE TABLE IF NOT EXISTS income" not in schema
    assert "CREATE TABLE IF NOT EXISTS expenses" not in schema
    assert "CREATE TABLE IF NOT EXISTS savings" not in schema


def test_seed_matches_demo_fixtures() -> None:
    seed = (SQL_ROOT / "seed" / "001_seed.sql").read_text(encoding="utf-8")
    assert len(_CATEGORIES) == 11
    assert len(_PERSONS) == 4
    assert "admin@voiceledger.local" in seed
    assert "demo@voiceledger.local" in seed
    assert seed.count("INSERT INTO loans") == 1
    assert "'Ravi Kumar'" in seed
    assert "'Priya Sharma'" in seed
    assert "compounding_frequency" in seed
    assert "seed-repayment-0002" in seed
    assert "SET NAMES utf8mb4;" in seed
    assert "UPDATE transactions SET loan_id = 1 WHERE id = 12;" in seed
    assert "UPDATE transactions SET loan_id = 2 WHERE id = 13;" in seed
    assert "UPDATE transactions SET loan_id = 3 WHERE id = 14;" in seed


def test_mongodb_collection_contract() -> None:
    assert COLLECTIONS == (
        "voice_commands",
        "audit_logs",
        "exchange_rates",
        "application_events",
    )


def test_required_documentation_exists() -> None:
    for relative in (
        "README.md",
        "docs/database/README.md",
        "docs/architecture/README.md",
        "docs/api/README.md",
        "docs/deployment/README.md",
        "integrations/api_contracts/README.md",
        "integrations/currency/README.md",
    ):
        assert (REPO_ROOT / relative).is_file()
