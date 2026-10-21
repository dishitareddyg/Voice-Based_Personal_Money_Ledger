from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pymongo.errors import PyMongoError
from sqlalchemy.exc import SQLAlchemyError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.context import get_request_id
from app.core.enums import ErrorCode
from app.core.errors import AppError, error_payload

logger = logging.getLogger(__name__)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=error_payload(
                exc.code,
                exc.message,
                details=exc.details,
                request_id=get_request_id(),
            ),
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_error(
        _: Request, exc: RequestValidationError
    ) -> JSONResponse:
        errors = [
            {
                "loc": list(error.get("loc", ())),
                "msg": error.get("msg", "Invalid value."),
                "type": error.get("type", "value_error"),
            }
            for error in exc.errors()
        ]
        message = "Please check the highlighted fields."
        if errors:
            first = errors[0]
            field = ".".join(str(part) for part in first["loc"] if part != "body")
            message = f"{field}: {first['msg']}" if field else first["msg"]
        return JSONResponse(
            status_code=422,
            content=error_payload(
                ErrorCode.VALIDATION_ERROR,
                message,
                details={"errors": errors},
                request_id=get_request_id(),
            ),
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(
        _: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        codes = {
            401: ErrorCode.UNAUTHORIZED,
            403: ErrorCode.FORBIDDEN,
            404: ErrorCode.NOT_FOUND,
            405: ErrorCode.METHOD_NOT_ALLOWED,
        }
        code = codes.get(exc.status_code, ErrorCode.VALIDATION_ERROR)
        return JSONResponse(
            status_code=exc.status_code,
            content=error_payload(
                code,
                str(exc.detail),
                request_id=get_request_id(),
            ),
            headers=getattr(exc, "headers", None),
        )

    @app.exception_handler(SQLAlchemyError)
    async def _database_error(_: Request, exc: SQLAlchemyError) -> JSONResponse:
        logger.exception("Database error", exc_info=exc)
        return JSONResponse(
            status_code=500,
            content=error_payload(
                ErrorCode.DATABASE_ERROR,
                "A database error occurred. Please try again.",
                request_id=get_request_id(),
            ),
        )

    @app.exception_handler(PyMongoError)
    async def _mongo_error(_: Request, exc: PyMongoError) -> JSONResponse:
        logger.exception("MongoDB error", exc_info=exc)
        return JSONResponse(
            status_code=503,
            content=error_payload(
                ErrorCode.SERVICE_UNAVAILABLE,
                "The analytics store is unavailable.",
                request_id=get_request_id(),
            ),
        )

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error", exc_info=exc)
        return JSONResponse(
            status_code=500,
            content=error_payload(
                ErrorCode.INTERNAL_ERROR,
                "An unexpected error occurred.",
                request_id=get_request_id(),
            ),
        )
