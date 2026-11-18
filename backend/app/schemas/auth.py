import uuid

from pydantic import BaseModel, ConfigDict

from app.models.enums import Currency
from app.schemas.fields import CurrencyField, Email, Name, Password


class RegisterIn(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {"email": "priya@example.com", "password": "secret123", "display_name": "Priya"}
            ]
        },
    )

    email: Email
    password: Password
    display_name: Name | None = None


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    default_currency: CurrencyField | None = None
    display_name: Name | None = None


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    display_name: str
    default_currency: Currency


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
