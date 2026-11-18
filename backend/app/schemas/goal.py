import uuid
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, JsonValue, field_validator
from pydantic_core import PydanticCustomError

from app.models import Goal
from app.models.enums import Currency, GoalAction, GoalType
from app.schemas.fields import (
    Corpus,
    CurrencyField,
    GoalTypeField,
    InflationPct,
    Name,
    ReturnPct,
    StepUpPct,
    TargetAmount,
    TargetDate,
)
from app.schemas.money import ScaledOut

_EXAMPLE: dict[str, JsonValue] = {
    "name": "Daughter's education",
    "goal_type": "education",
    "currency": "INR",
    "target_amount": "10000000.00",
    "target_date": "2038-11-18",
    "current_corpus": "20000.00",
    "expected_return_pct": "12",
    "annual_step_up_pct": "10",
    "inflation_pct": "6",
}

FIELD_TO_COLUMN = {
    "name": "name",
    "goal_type": "goal_type",
    "target_amount": "target_amount",
    "target_date": "target_date",
    "current_corpus": "current_corpus",
    "expected_return_pct": "expected_return_bp",
    "annual_step_up_pct": "annual_step_up_bp",
    "inflation_pct": "inflation_bp",
}
MONEY_FIELDS = ("target_amount", "current_corpus")


class GoalCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", json_schema_extra={"examples": [_EXAMPLE]})

    name: Name
    goal_type: GoalTypeField
    currency: CurrencyField | None = None
    target_amount: TargetAmount
    target_date: TargetDate
    current_corpus: Corpus = 0
    expected_return_pct: ReturnPct
    annual_step_up_pct: StepUpPct = 0
    inflation_pct: InflationPct = 200


class GoalUpdate(BaseModel):
    """Partial update. Omitted fields are left unchanged; `null` is not allowed."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={"examples": [{"current_corpus": "50000.00", "annual_step_up_pct": "5"}]},
    )

    name: Name | None = None
    goal_type: GoalTypeField | None = None
    target_amount: TargetAmount | None = None
    target_date: TargetDate | None = None
    current_corpus: Corpus | None = None
    expected_return_pct: ReturnPct | None = None
    annual_step_up_pct: StepUpPct | None = None
    inflation_pct: InflationPct | None = None
    # Declared only so a sent currency gets a clear `currency_locked` error.
    currency: Any = None

    @field_validator("currency", mode="before")
    @classmethod
    def _currency_locked(cls, value: Any) -> Any:
        if value is not None:
            raise PydanticCustomError(
                "currency_locked",
                "A goal's currency can't be changed. Create a new goal instead.",
            )
        return value

    def changed_fields(self) -> dict[str, Any]:
        """Fields the client actually sent with a non-null value (currency excluded)."""
        return {
            k: getattr(self, k)
            for k in self.model_fields_set
            if k in FIELD_TO_COLUMN and getattr(self, k) is not None
        }


class GoalOut(BaseModel):
    id: uuid.UUID
    name: str
    goal_type: GoalType
    currency: Currency
    target_amount: ScaledOut
    target_date: date
    current_corpus: ScaledOut
    expected_return_pct: ScaledOut
    annual_step_up_pct: ScaledOut
    inflation_pct: ScaledOut
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_model(cls, goal: Goal) -> "GoalOut":
        return cls(
            id=goal.id,
            name=goal.name,
            goal_type=goal.goal_type,
            currency=goal.currency,
            target_amount=goal.target_amount,
            target_date=goal.target_date,
            current_corpus=goal.current_corpus,
            expected_return_pct=goal.expected_return_bp,
            annual_step_up_pct=goal.annual_step_up_bp,
            inflation_pct=goal.inflation_bp,
            created_at=goal.created_at,
            updated_at=goal.updated_at,
        )


class GoalLogOut(BaseModel):
    id: uuid.UUID
    action: GoalAction
    changes: dict[str, Any]
    created_at: datetime
