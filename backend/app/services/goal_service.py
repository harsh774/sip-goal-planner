import uuid
from collections.abc import Sequence
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy.orm import Session

from app.core.errors import FieldError, NotFoundError
from app.models import Goal, GoalLog, User
from app.models.enums import CURRENCY_DECIMALS, Currency, GoalAction
from app.repositories import GoalLogRepository, GoalRepository
from app.schemas.goal import FIELD_TO_COLUMN, MONEY_FIELDS, GoalCreate, GoalUpdate
from app.schemas.money import SCALE, format_scaled
from app.services.projection import Projection, ProjectionInput, project


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

    def list(self, user: User) -> Sequence[Goal]:
        return self._goals.list_for_user(user.id)

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
        inputs = ProjectionInput(
            target=goal.target_amount / SCALE,
            corpus=goal.current_corpus / SCALE,
            annual_return=goal.expected_return_bp / 10_000,
            annual_step_up=goal.annual_step_up_bp / 10_000,
            inflation=goal.inflation_bp / 10_000,
            as_of=as_of or date.today(),
            target_date=goal.target_date,
        )
        return goal, project(inputs)

    def _log(self, goal: Goal, user: User, action: GoalAction, changes: dict[str, Any]) -> None:
        self._logs.add(GoalLog(goal_id=goal.id, user_id=user.id, action=action, changes=changes))

    def _commit(self, goal: Goal) -> Goal:
        self._db.commit()
        self._db.refresh(goal)
        return goal
