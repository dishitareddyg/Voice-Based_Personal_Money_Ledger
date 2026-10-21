"""Logging setup that never records request bodies or credentials."""

from __future__ import annotations

import logging

from app.core.context import get_request_id


class _RequestIdFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = get_request_id() or "-"
        return True


def configure_logging(level: str = "INFO") -> None:
    root = logging.getLogger()
    if not root.handlers:
        logging.basicConfig(
            level=getattr(logging, level.upper(), logging.INFO),
            format="%(asctime)s %(levelname)s %(name)s [%(request_id)s] %(message)s",
        )
    for handler in root.handlers:
        if not any(isinstance(f, _RequestIdFilter) for f in handler.filters):
            handler.addFilter(_RequestIdFilter())
    logging.getLogger("pymongo").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
