"""Test configuration.

Environment variables are set before the application (and its database engine)
is imported. Pure unit tests never open a database connection. Tests that use the
``mysql_db`` fixture need a reachable MySQL 8 (TEST_DATABASE_URL) and skip
themselves otherwise (set REQUIRE_MYSQL=1 to make that a failure). Tests
marked ``integration`` additionally require RUN_INTEGRATION=1.
"""

from __future__ import annotations

import os

os.environ["ENVIRONMENT"] = "test"
os.environ["DATABASE_URL"] = os.getenv(
    "TEST_DATABASE_URL",
    "mysql+pymysql://test:test@127.0.0.1:3306/voice_ledger_test?charset=utf8mb4",
)
os.environ["JWT_SECRET_KEY"] = "test-secret-key-at-least-32-characters-long"
os.environ.pop("ADMIN_EMAIL", None)
os.environ.pop("ADMIN_PASSWORD", None)

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="session")
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def mysql_db():
    """Migrate the test database to head; skip if MySQL is unreachable."""
    from alembic.config import Config
    from sqlalchemy import text

    from alembic import command
    from app.database.mysql.session import engine

    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:
        if os.getenv("REQUIRE_MYSQL") == "1":
            raise
        pytest.skip(f"MySQL test database unreachable: {exc}")
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    config = Config(os.path.join(root, "alembic.ini"))
    config.set_main_option("script_location", os.path.join(root, "alembic"))
    command.upgrade(config, "head")
    return engine


@pytest.fixture()
def make_user(mysql_db):
    """Factory creating committed users (needed for FK-backed rows)."""
    import uuid

    from app.database.mysql.session import SessionLocal
    from app.repositories import user_repository

    def _make() -> int:
        with SessionLocal() as db:
            user = user_repository.create(
                db,
                full_name="Test User",
                email=f"t-{uuid.uuid4().hex[:12]}@example.com",
                password_hash="x",
            )
            db.commit()
            return user.id

    return _make
