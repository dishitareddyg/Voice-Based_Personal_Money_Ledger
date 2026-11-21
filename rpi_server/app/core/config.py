"""Application settings loaded from environment variables / .env."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from urllib.parse import quote_plus

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env",),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Voice Ledger API"
    app_version: str = "1.0.0"
    environment: str = "development"
    debug: bool = False
    log_level: str = "INFO"
    api_prefix: str = "/api/v1"

    # MySQL -----------------------------------------------------------------
    database_url: str | None = None
    mysql_host: str = "127.0.0.1"
    mysql_port: int = 3306
    mysql_user: str = "voice_ledger"
    mysql_password: str = "change-me"
    mysql_database: str = "voice_ledger"
    mysql_charset: str = "utf8mb4"

    # Connection pool, sized for a 2 GB Raspberry Pi: each Uvicorn worker keeps
    # at most db_pool_size + db_max_overflow connections (see my.cnf).
    db_pool_size: int = 5
    db_max_overflow: int = 5

    # Auth ------------------------------------------------------------------
    jwt_secret_key: str = "change-me-to-a-long-random-secret"
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "voice-ledger"
    access_token_expire_minutes: int = 720
    password_min_length: int = 8

    # Locale ----------------------------------------------------------------
    default_timezone: str = "Asia/Kolkata"

    # Currency --------------------------------------------------------------
    exchange_rate_base_url: str = "https://open.er-api.com/v6/latest"
    exchange_rate_cache_minutes: int = 60
    exchange_rate_timeout_seconds: float = 8.0

    # Admin bootstrap -------------------------------------------------------
    admin_email: str | None = None
    admin_password: str | None = None
    admin_full_name: str = "Ledger Administrator"

    # Maintenance -----------------------------------------------------------
    backup_dir: Path = Field(default=Path("/var/backups/voice_ledger"))
    alembic_config_path: Path = Field(default=Path("alembic.ini"))
    project_root: Path = Field(default_factory=lambda: Path(__file__).resolve().parents[2])

    @property
    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        user = quote_plus(self.mysql_user)
        password = quote_plus(self.mysql_password)
        return (
            f"mysql+pymysql://{user}:{password}@"
            f"{self.mysql_host}:{self.mysql_port}/{self.mysql_database}"
            f"?charset={self.mysql_charset}"
        )

    @property
    def is_test(self) -> bool:
        return self.environment.lower() == "test"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
