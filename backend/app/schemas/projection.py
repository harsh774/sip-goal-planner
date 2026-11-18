from dataclasses import asdict
from datetime import date

from pydantic import BaseModel

from app.models import Goal
from app.models.enums import Currency
from app.schemas.money import DecimalOut, ScaledOut
from app.services.projection import Plan, Projection

ASSUMPTIONS_NOTE = (
    "Returns are illustrative assumptions, not guaranteed. "
    "Mutual fund investments are subject to market risks."
)


class ScheduleRowOut(BaseModel):
    year: int
    calendar_year: int
    months: int
    monthly_sip: DecimalOut
    invested_to_date: DecimalOut
    growth_to_date: DecimalOut
    closing_balance: DecimalOut
    goal_pct: DecimalOut


class PlanOut(BaseModel):
    step_up_pct: ScaledOut
    first_year_sip: DecimalOut
    final_year_sip: DecimalOut
    total_invested: DecimalOut
    growth: DecimalOut
    final_balance: DecimalOut
    rows: list[ScheduleRowOut]

    @classmethod
    def from_plan(cls, plan: Plan) -> "PlanOut":
        return cls(
            step_up_pct=round(plan.annual_step_up * 10_000),
            first_year_sip=plan.first_year_sip,
            final_year_sip=plan.final_year_sip,
            total_invested=plan.total_invested,
            growth=plan.growth,
            final_balance=plan.final_balance,
            rows=[ScheduleRowOut(**asdict(row)) for row in plan.rows],
        )


class ProjectionOut(BaseModel):
    as_of: date
    months: int
    currency: Currency
    monthly_rate: float
    target_amount: ScaledOut
    current_corpus: ScaledOut
    corpus_future_value: DecimalOut
    gap: DecimalOut
    today_value: DecimalOut
    on_track: bool
    assumptions_note: str = ASSUMPTIONS_NOTE
    level: PlanOut
    step_up: PlanOut

    @classmethod
    def build(cls, goal: Goal, projection: Projection) -> "ProjectionOut":
        return cls(
            as_of=projection.as_of,
            months=projection.months,
            currency=goal.currency,
            monthly_rate=round(projection.monthly_rate, 10),
            target_amount=goal.target_amount,
            current_corpus=goal.current_corpus,
            corpus_future_value=projection.corpus_future_value,
            gap=projection.gap,
            today_value=projection.today_value,
            on_track=projection.on_track,
            level=PlanOut.from_plan(projection.level),
            step_up=PlanOut.from_plan(projection.step_up),
        )
