import math
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy.orm import Session

from app.core.errors import FieldError, NotFoundError
from app.models import Goal, GoalLog, User
from app.models.enums import CURRENCY_DECIMALS, Currency, GoalAction
from app.repositories import GoalLogRepository, GoalRepository
from app.schemas.goal import FIELD_TO_COLUMN, MONEY_FIELDS, GoalCreate, GoalUpdate
from app.schemas.goal_query import GoalListParams, GoalSummaryParams
from app.schemas.money import SCALE, format_float, format_scaled
from app.services import fx
from app.services.projection import Projection, ProjectionInput, project, round_money


def snapshot(goal: Goal) -> dict[str, str]:
    """A goal's editable state in API string form, as recorded in its history."""
    return {
        "name": goal.name,
        "goal_type": goal.goal_type.value,
        "currency": goal.currency.value,
        "target_amount": format_scaled(goal.target_amount),
        "target_date": goal.target_date.isoformat(),
        "current_corpus": format_scaled(goal.current_corpus),
        "expected_return_pct": format_scaled(goal.expected_return_bp),
        "annual_step_up_pct": format_scaled(goal.annual_step_up_bp),
        "inflation_pct": format_scaled(goal.inflation_bp),
    }


@dataclass(frozen=True)
class GoalPage:
    items: Sequence[Goal]
    page: int
    page_size: int
    total: int

    @property
    def total_pages(self) -> int:
        return math.ceil(self.total / self.page_size)


@dataclass(frozen=True)
class GoalTotals:
    count: int
    currency: Currency
    total_monthly_sip: float
    total_target: float
    converted: bool
    rates_as_of: date


def projection_input(goal: Goal, as_of: date) -> ProjectionInput:
    return ProjectionInput(
        target=goal.target_amount / SCALE,
        corpus=goal.current_corpus / SCALE,
        annual_return=goal.expected_return_bp / 10_000,
        annual_step_up=goal.annual_step_up_bp / 10_000,
        inflation=goal.inflation_bp / 10_000,
        as_of=as_of,
        target_date=goal.target_date,
    )


def _diff(before: dict[str, str], after: dict[str, str]) -> dict[str, dict[str, str]]:
    return {k: {"old": before[k], "new": after[k]} for k in after if before[k] != after[k]}


def _ensure_currency_precision(currency: Currency, values: dict[str, Any]) -> None:
    if CURRENCY_DECIMALS[currency] > 0:
        return
    for field in MONEY_FIELDS:
        value = values.get(field)
        if value is not None and value % SCALE:
            raise FieldError(field, "too_many_decimals", f"{currency} amounts can't have decimals.")


class GoalService:
    def __init__(self, db: Session) -> None:
        self._db = db
        self._goals = GoalRepository(db)
        self._logs = GoalLogRepository(db)

    def page(self, user: User, params: GoalListParams) -> GoalPage:
        self.complete_due(user, date.today())
        if params.q:
            return self._search(user, params)
        items, total = self._goals.page_for_user(
            user.id,
            params,
            params.sort,
            offset=(params.page - 1) * params.page_size,
            limit=params.page_size,
            exclude_completed=params.exclude_completed,
        )
        return GoalPage(items=items, page=params.page, page_size=params.page_size, total=total)

    def _search(self, user: User, params: GoalListParams) -> GoalPage:
        # Names are encrypted at rest, so SQL can't match them: the other filters narrow the
        # rows in SQL, then names are matched after decryption. One user's goals are few.
        needle = (params.q or "").casefold()
        matches = [
            g
            for g in self._goals.all_matching(
                user.id, params, params.sort, params.exclude_completed
            )
            if needle in g.name.casefold()
        ]
        start = (params.page - 1) * params.page_size
        return GoalPage(
            items=matches[start : start + params.page_size],
            page=params.page,
            page_size=params.page_size,
            total=len(matches),
        )

    def summary(self, user: User, params: GoalSummaryParams) -> GoalTotals:
        """Level SIPs and targets of every matching goal, added up in one currency."""
        currency = params.in_currency or user.default_currency
        as_of = params.as_of or date.today()
        goals = self._goals.all_matching(user.id, params)

        sip = target = 0.0
        for goal in goals:
            plan = project(projection_input(goal, as_of)).level
            sip += round_money(fx.convert(plan.first_year_sip, goal.currency, currency))
            target += round_money(fx.convert(goal.target_amount / SCALE, goal.currency, currency))

        return GoalTotals(
            count=len(goals),
            currency=currency,
            total_monthly_sip=round_money(sip),
            total_target=round_money(target),
            converted=any(g.currency != currency for g in goals),
            rates_as_of=fx.RATES_AS_OF,
        )

    def get(self, user: User, goal_id: uuid.UUID) -> Goal:
        goal = self._goals.get_for_user(goal_id, user.id)
        if goal is None:
            raise NotFoundError("Goal not found.")
        return goal

    def create(self, user: User, data: GoalCreate) -> Goal:
        currency = data.currency or user.default_currency
        _ensure_currency_precision(currency, {f: getattr(data, f) for f in MONEY_FIELDS})

        goal = Goal(
            user_id=user.id,
            currency=currency,
            **{column: getattr(data, field) for field, column in FIELD_TO_COLUMN.items()},
        )
        self._goals.add(goal)
        self._log(goal, user, GoalAction.CREATED, snapshot(goal))
        return self._commit(goal)

    def update(self, user: User, goal_id: uuid.UUID, data: GoalUpdate) -> Goal:
        goal = self.get(user, goal_id)
        changes = data.changed_fields()
        _ensure_currency_precision(goal.currency, changes)

        before = snapshot(goal)
        for field, value in changes.items():
            setattr(goal, FIELD_TO_COLUMN[field], value)
        diff = _diff(before, snapshot(goal))
        if not diff:
            return goal

        goal.updated_at = datetime.now(UTC)
        self._log(goal, user, GoalAction.UPDATED, diff)
        return self._commit(goal)

    def delete(self, user: User, goal_id: uuid.UUID) -> None:
        goal = self.get(user, goal_id)
        goal.deleted_at = datetime.now(UTC)
        self._log(goal, user, GoalAction.DELETED, snapshot(goal))
        self._db.commit()

    def history(self, user: User, goal_id: uuid.UUID) -> Sequence[GoalLog]:
        goal = self.get(user, goal_id)
        return self._logs.list_for_goal(goal.id)

    def projection(
        self, user: User, goal_id: uuid.UUID, as_of: date | None
    ) -> tuple[Goal, Projection]:
        goal = self.get(user, goal_id)
        return goal, project(projection_input(goal, as_of or date.today()))

    def complete_due(self, user: User, today: date) -> int:
        """Marks goals whose target date has arrived as completed; returns how many.

        The app doesn't record real payments, so a goal counts as completed when its target
        date has passed and the plan in force (projected from the newest history row, i.e.
        the last create or edit) reaches the target: total invested plus growth ≥ target.
        Each completion writes a `completed` history row; all commit together.
        """
        completed = 0
        for goal in self._goals.due_for_completion(user.id, today):
            latest = self._logs.latest_for_goal(goal.id)
            plan_from = latest.created_at.date() if latest else goal.created_at.date()
            plan = project(projection_input(goal, plan_from)).level
            if plan.final_balance < goal.target_amount / SCALE:
                continue
            self._log(
                goal,
                user,
                GoalAction.COMPLETED,
                {
                    "plan_from": plan_from.isoformat(),
                    "target_date": goal.target_date.isoformat(),
                    "target_amount": format_scaled(goal.target_amount),
                    "monthly_sip": format_float(plan.first_year_sip),
                    "total_invested": format_float(plan.total_invested),
                    "final_balance": format_float(plan.final_balance),
                },
            )
            completed += 1
        if completed:
            self._db.commit()
        else:
            self._db.rollback()  # releases the row locks
        return completed

    def _log(self, goal: Goal, user: User, action: GoalAction, changes: dict[str, Any]) -> None:
        goal.action = action
        self._logs.add(GoalLog(goal_id=goal.id, user_id=user.id, action=action, changes=changes))

    def _commit(self, goal: Goal) -> Goal:
        self._db.commit()
        self._db.refresh(goal)
        return goal
