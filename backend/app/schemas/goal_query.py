from datetime import date
from enum import StrEnum
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, model_validator
from pydantic_core import PydanticCustomError

from app.models.enums import Currency
from app.schemas.fields import CurrencyField, GoalTypeField
from app.schemas.goal import GoalOut
from app.schemas.money import DecimalOut, Scaled

MIN_YEAR, MAX_YEAR = 2000, 2200


class GoalSort(StrEnum):
    NEWEST = "newest"
    TARGET_DATE = "target_date"
    TARGET_AMOUNT = "target_amount"


Year = Annotated[int, Field(ge=MIN_YEAR, le=MAX_YEAR)]


class GoalFilters(BaseModel):
    """Optional filters shared by the goal list and the summary. Amounts are in each goal's
    own currency, so an amount range is only meaningful together with a `currency` filter."""

    model_config = ConfigDict(extra="forbid")

    currency: CurrencyField | None = None
    goal_type: GoalTypeField | None = None
    min_target_amount: Scaled | None = None
    max_target_amount: Scaled | None = None
    target_year_from: Year | None = None
    target_year_to: Year | None = None

    @model_validator(mode="after")
    def _ranges_in_order(self) -> "GoalFilters":
        if (
            self.min_target_amount is not None
            and self.max_target_amount is not None
            and self.min_target_amount > self.max_target_amount
        ):
            raise PydanticCustomError(
                "amount_range_invalid", "Minimum amount must not exceed maximum amount."
            )
        if (
            self.target_year_from is not None
            and self.target_year_to is not None
            and self.target_year_from > self.target_year_to
        ):
            raise PydanticCustomError("year_range_invalid", "'From' year must not be after 'to'.")
        return self

    @property
    def target_date_from(self) -> date | None:
        return date(self.target_year_from, 1, 1) if self.target_year_from else None

    @property
    def target_date_before(self) -> date | None:
        return date(self.target_year_to + 1, 1, 1) if self.target_year_to else None


def _search_text(value: object) -> object:
    if not isinstance(value, str):
        return value
    value = value.strip()
    if len(value) > 100:
        raise PydanticCustomError("search_too_long", "Search with at most 100 characters.")
    return value or None


SearchText = Annotated[str | None, BeforeValidator(_search_text)]


class GoalListParams(GoalFilters):
    # Matches goal names containing this text, ignoring case.
    q: SearchText = None
    page: Annotated[int, Field(ge=1)] = 1
    page_size: Annotated[int, Field(ge=1, le=100)] = 10
    sort: GoalSort = GoalSort.NEWEST


class GoalSummaryParams(GoalFilters):
    # The currency to add totals up in; `currency` (inherited) filters goals instead.
    in_currency: CurrencyField | None = None
    as_of: date | None = None


class GoalPageOut(BaseModel):
    items: list[GoalOut]
    page: int
    page_size: int
    total: int
    total_pages: int


class GoalSummaryOut(BaseModel):
    count: int
    currency: Currency
    total_monthly_sip: DecimalOut
    total_target: DecimalOut
    converted: bool
    rates_as_of: date
