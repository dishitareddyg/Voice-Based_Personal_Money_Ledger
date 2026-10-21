from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.mongodb.client import get_mongo_database
from app.database.mysql.session import get_db

logger = logging.getLogger(__name__)

router = APIRouter(tags=["health"])


@router.get("/")
def root() -> dict[str, str]:
    settings = get_settings()
    return {
        "service": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "health": "/health",
    }


@router.get("/health")
def health() -> dict[str, str]:
    settings = get_settings()
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
    }


@router.get("/health/ready")
def readiness(db: Session = Depends(get_db)) -> JSONResponse:
    checks: dict[str, str] = {}
    try:
        db.execute(text("SELECT 1"))
        checks["mysql"] = "ok"
    except Exception as exc:
        logger.warning("MySQL readiness check failed: %s", exc)
        checks["mysql"] = "unavailable"
    try:
        get_mongo_database().ping()
        checks["mongodb"] = "ok"
    except Exception as exc:
        logger.warning("MongoDB readiness check failed: %s", exc)
        checks["mongodb"] = "unavailable"

    ready = all(value == "ok" for value in checks.values())
    return JSONResponse(
        status_code=200 if ready else 503,
        content={
            "status": "ready" if ready else "degraded",
            "checks": checks,
        },
    )
