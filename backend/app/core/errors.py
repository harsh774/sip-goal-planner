"""Application errors and the single JSON error shape the API returns.

Validation errors: 422 {"detail": [{"field": str | null, "code": str, "message": str}]}
Other errors:      {"detail": str}
"""

from fastapi import Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

_LOCATION_PREFIXES = {"body", "query", "path", "header", "cookie"}


class FieldError(Exception):
    """A validation failure found outside Pydantic (e.g. needs the database)."""

    def __init__(
        self,
        field: str | None,
        code: str,
        message: str,
        status_code: int = status.HTTP_422_UNPROCESSABLE_CONTENT,
    ) -> None:
        super().__init__(message)
        self.field = field
        self.code = code
        self.message = message
        self.status_code = status_code


class NotFoundError(Exception):
    def __init__(self, message: str = "Not found.") -> None:
        super().__init__(message)
        self.message = message


def _field_from_loc(loc: tuple) -> str | None:
    parts = [str(p) for p in loc if p not in _LOCATION_PREFIXES]
    return ".".join(parts) if parts else None


async def request_validation_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    detail = [
        {
            "field": _field_from_loc(tuple(err.get("loc", ()))),
            "code": err.get("type", "invalid"),
            "message": err.get("msg", "Invalid value."),
        }
        for err in exc.errors()
    ]
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        content=jsonable_encoder({"detail": detail}),
    )


async def field_error_handler(_: Request, exc: FieldError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": [{"field": exc.field, "code": exc.code, "message": exc.message}]},
    )


async def not_found_handler(_: Request, exc: NotFoundError) -> JSONResponse:
    return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"detail": exc.message})
