"""Apply every Alembic migration (idempotent).

    python -m app.scripts.init_db

Creates or upgrades all MySQL tables, including ``VOICE_COMMAND``,
``AUDIT_LOG``, ``APPLICATION_EVENT`` and ``EXCHANGE_RATE_CACHE``. Equivalent
to ``alembic upgrade head``; it replaces the former document-store
initialisation step.
"""

from __future__ import annotations

from alembic.config import Config

from alembic import command
from app.core.config import get_settings


def main() -> None:
    settings = get_settings()
    path = settings.alembic_config_path
    if not path.is_absolute():
        path = settings.project_root / path
    config = Config(str(path))
    config.set_main_option(
        "script_location", str(settings.project_root / "alembic")
    )
    command.upgrade(config, "head")
    print("MySQL schema is up to date (alembic head).")


if __name__ == "__main__":
    main()
