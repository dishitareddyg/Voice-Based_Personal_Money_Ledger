"""Create MongoDB collections and indexes for the Voice Ledger.

Usage:
    python -m app.scripts.init_mongo

This is idempotent. MySQL remains the authoritative store; MongoDB holds only
voice metadata, audit logs, application events and the exchange-rate cache.
"""

from __future__ import annotations

from app.database.mongodb.client import COLLECTIONS, get_mongo_database


def main() -> None:
    database = get_mongo_database()
    database.ensure_indexes()
    print(
        f"MongoDB ready: {database.database.name} "
        f"({', '.join(COLLECTIONS)})"
    )


if __name__ == "__main__":
    main()
