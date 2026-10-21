"""Lazy MongoDB client and collection/index definitions.

Creating a MongoClient does not open a socket, so importing the application is
safe even when MongoDB is not running. Both databases must be available for a
fully ready deployment; see /health/ready.

MongoDB stores semi-structured supporting data only:
``voice_commands``, ``audit_logs``, ``exchange_rates`` and
``application_events``. It is never authoritative for a balance, loan or
repayment.
"""

from __future__ import annotations

from pymongo import ASCENDING, DESCENDING, MongoClient
from pymongo.database import Database

from app.core.config import get_settings

COLLECTIONS = (
    "voice_commands",
    "audit_logs",
    "exchange_rates",
    "application_events",
)


class MongoDatabase:
    def __init__(self, uri: str | None = None, database: str | None = None) -> None:
        settings = get_settings()
        self._uri = uri or settings.mongodb_uri
        self._database_name = database or settings.mongodb_database
        self._timeout_ms = settings.mongodb_timeout_ms
        self._client: MongoClient | None = None

    @property
    def client(self) -> MongoClient:
        if self._client is None:
            self._client = MongoClient(
                self._uri,
                serverSelectionTimeoutMS=self._timeout_ms,
                tz_aware=True,
            )
        return self._client

    @property
    def database(self) -> Database:
        return self.client[self._database_name]

    def ping(self) -> bool:
        self.client.admin.command("ping")
        return True

    def close(self) -> None:
        if self._client is not None:
            self._client.close()
            self._client = None

    def ensure_indexes(self) -> None:
        """Create collections/indexes idempotently.

        Index creation also creates the collection. This runs at application
        startup and from ``python -m app.scripts.init_mongo``.
        """

        db = self.database

        db["voice_commands"].create_index(
            [("user_id", ASCENDING), ("created_at", DESCENDING)]
        )
        db["voice_commands"].create_index(
            [("user_id", ASCENDING), ("request_id", ASCENDING)],
            unique=True,
            name="uq_voice_commands_user_request",
        )
        db["voice_commands"].create_index("transaction_id")

        db["audit_logs"].create_index(
            [("user_id", ASCENDING), ("created_at", DESCENDING)]
        )
        db["audit_logs"].create_index("request_id")
        db["audit_logs"].create_index(
            [("event_type", ASCENDING), ("created_at", DESCENDING)]
        )

        db["exchange_rates"].create_index(
            [("base_currency", ASCENDING), ("target_currency", ASCENDING)],
            unique=True,
            name="uq_exchange_rates_pair",
        )
        db["exchange_rates"].create_index(
            [
                ("base_currency", ASCENDING),
                ("target_currency", ASCENDING),
                ("retrieved_at", DESCENDING),
            ]
        )
        db["exchange_rates"].create_index(
            [
                ("base_currency", ASCENDING),
                ("target_currency", ASCENDING),
                ("valid_until", DESCENDING),
            ]
        )

        db["application_events"].create_index(
            [("user_id", ASCENDING), ("created_at", DESCENDING)]
        )
        db["application_events"].create_index(
            [("event_type", ASCENDING), ("created_at", DESCENDING)]
        )
        db["application_events"].create_index("request_id")


mongo_database = MongoDatabase()


def get_mongo_database() -> MongoDatabase:
    return mongo_database
