"""Test configuration.

Environment variables are set before the application (and its database engine)
is imported. Unit tests never open a MySQL or MongoDB connection; tests marked
``integration`` require RUN_INTEGRATION=1 and live services.
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
