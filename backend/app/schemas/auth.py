import uuid

from pydantic import BaseModel, ConfigDict

from app.models.enums import Currency
from app.schemas.fields import CurrencyField, Email, FirstName, LastName, Password


class RegisterIn(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "first_name": "Priya",
                    "last_name": "Sharma",
                    "email": "priya@example.com",
                    "password": "secret123",
                }
            ]
        },
    )

    first_name: FirstName
    last_name: LastName
    email: Email
    password: Password


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    default_currency: CurrencyField | None = None
    first_name: FirstName | None = None
    last_name: LastName | None = None


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    first_name: str
    last_name: str
    default_currency: Currency


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
