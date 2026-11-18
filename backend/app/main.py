from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, goals
from app.core.config import get_settings
from app.core.errors import (
    FieldError,
    NotFoundError,
    field_error_handler,
    not_found_handler,
    request_validation_handler,
)

API_PREFIX = "/api/v1"

DESCRIPTION = """
Plan savings goals and see the monthly SIP needed to reach them.

**How to try it:** register with `POST /auth/register`, click **Authorize**,
log in with your email as the username, then call the goal endpoints.

Money and percentages are sent and returned as **strings** (`"2500000.50"`, `"12.5"`).

*Returns are illustrative assumptions, not guarantees.
Mutual fund investments are subject to market risks.*
"""


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="SIP Goal Planner API", version="1.0.0", description=DESCRIPTION)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.add_exception_handler(RequestValidationError, request_validation_handler)
    app.add_exception_handler(FieldError, field_error_handler)
    app.add_exception_handler(NotFoundError, not_found_handler)

    app.include_router(auth.router, prefix=API_PREFIX)
    app.include_router(goals.router, prefix=API_PREFIX)

    @app.get("/health", tags=["meta"])
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
