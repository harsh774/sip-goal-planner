"""Reusable validated field types. Every failure raises a stable `code` the client can map."""

import re
from datetime import date
from typing import Annotated

from email_validator import EmailNotValidError, validate_email
from pydantic import AfterValidator, BeforeValidator
from pydantic_core import PydanticCustomError

from app.models.enums import Currency, GoalType
from app.schemas.money import Scaled

MAX_AMOUNT = 1_000_000_000_000 * 100  # hundredths
MAX_YEARS_AHEAD = 100


def _strip(value: object) -> object:
    return value.strip() if isinstance(value, str) else value


def _check_email(value: str) -> str:
    try:
        return validate_email(value, check_deliverability=False).normalized.lower()
    except EmailNotValidError:
        raise PydanticCustomError("email_invalid", "Enter a valid email address.") from None


def _check_password(value: str) -> str:
    if len(value.encode("utf-8")) > 72:
        raise PydanticCustomError("password_too_long", "Use at most 72 characters.")
    if len(value) < 8 or not re.search(r"[A-Za-z]", value) or not re.search(r"\d", value):
        raise PydanticCustomError(
            "password_weak", "Use at least 8 characters, including a letter and a number."
        )
    return value


def _check_name(value: str) -> str:
    if not value:
        raise PydanticCustomError("name_required", "Name is required.")
    if len(value) > 100:
        raise PydanticCustomError("name_too_long", "Use at most 100 characters.")
    return value


Email = Annotated[str, BeforeValidator(_strip), AfterValidator(_check_email)]
Password = Annotated[str, AfterValidator(_check_password)]
Name = Annotated[str, BeforeValidator(_strip), AfterValidator(_check_name)]


def _currency(value: object) -> Currency:
    try:
        return Currency(value)
    except ValueError:
        raise PydanticCustomError("currency_invalid", "Unsupported currency.") from None


def _goal_type(value: object) -> GoalType:
    try:
        return GoalType(value)
    except ValueError:
        raise PydanticCustomError("goal_type_invalid", "Choose a goal type.") from None


CurrencyField = Annotated[Currency, BeforeValidator(_currency)]
GoalTypeField = Annotated[GoalType, BeforeValidator(_goal_type)]


def _target_amount(value: int) -> int:
    if value <= 0:
        raise PydanticCustomError("amount_positive", "Target amount must be greater than 0.")
    if value > MAX_AMOUNT:
        raise PydanticCustomError("amount_too_large", "Target amount is too large.")
    return value


def _corpus(value: int) -> int:
    if value < 0:
        raise PydanticCustomError("amount_negative", "Amount already invested cannot be negative.")
    if value > MAX_AMOUNT:
        raise PydanticCustomError("amount_too_large", "Amount already invested is too large.")
    return value


TargetAmount = Annotated[Scaled, AfterValidator(_target_amount)]
Corpus = Annotated[Scaled, AfterValidator(_corpus)]


def _bp_range(max_pct: int, code: str, label: str):
    def check(value: int) -> int:
        if not 0 <= value <= max_pct * 100:
            raise PydanticCustomError(code, f"{label} must be between 0% and {max_pct}%.")
        return value

    return AfterValidator(check)


ReturnPct = Annotated[Scaled, _bp_range(30, "return_range", "Expected return")]
StepUpPct = Annotated[Scaled, _bp_range(25, "step_up_range", "Yearly increase")]
InflationPct = Annotated[Scaled, _bp_range(12, "inflation_range", "Inflation")]


def _target_date(value: date) -> date:
    today = date.today()
    if value <= today:
        raise PydanticCustomError("date_past", "Target date must be in the future.")
    if value.year > today.year + MAX_YEARS_AHEAD:
        raise PydanticCustomError(
            "date_too_far", f"Target date must be within {MAX_YEARS_AHEAD} years."
        )
    return value


TargetDate = Annotated[date, AfterValidator(_target_date)]
