import uuid
from collections.abc import Sequence
from datetime import date

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.models import Goal, GoalLog
from app.models.enums import GoalAction
from app.schemas.goal_query import GoalFilters, GoalSort

_ORDER = {
    GoalSort.NEWEST: (Goal.id.desc(),),
    GoalSort.TARGET_DATE: (Goal.target_date.asc(), Goal.id.asc()),
    GoalSort.TARGET_AMOUNT: (Goal.target_amount.desc(), Goal.id.asc()),
}


class GoalRepository:
    """Data access for goals. Every query is scoped to one user and skips soft-deleted rows."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def page_for_user(
        self,
        user_id: uuid.UUID,
        filters: GoalFilters,
        sort: GoalSort,
        offset: int,
        limit: int,
        exclude_completed: bool = False,
    ) -> tuple[Sequence[Goal], int]:
        stmt = self._matching(user_id, filters, exclude_completed)
        total = self._db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        items = self._db.scalars(stmt.order_by(*_ORDER[sort]).offset(offset).limit(limit)).all()
        return items, total

    def all_matching(
        self,
        user_id: uuid.UUID,
        filters: GoalFilters,
        sort: GoalSort | None = None,
        exclude_completed: bool = False,
    ) -> Sequence[Goal]:
        stmt = self._matching(user_id, filters, exclude_completed)
        if sort is not None:
            stmt = stmt.order_by(*_ORDER[sort])
        return self._db.scalars(stmt).all()

    @staticmethod
    def _matching(
        user_id: uuid.UUID, f: GoalFilters, exclude_completed: bool = False
    ) -> Select[Goal]:
        stmt = select(Goal).where(Goal.user_id == user_id, Goal.deleted_at.is_(None))
        if exclude_completed:
            stmt = stmt.where(Goal.action != GoalAction.COMPLETED)
        if f.currency is not None:
            stmt = stmt.where(Goal.currency == f.currency)
        if f.goal_type is not None:
            stmt = stmt.where(Goal.goal_type == f.goal_type)
        if f.min_target_amount is not None:
            stmt = stmt.where(Goal.target_amount >= f.min_target_amount)
        if f.max_target_amount is not None:
            stmt = stmt.where(Goal.target_amount <= f.max_target_amount)
        # Date bounds rather than EXTRACT(year), so the (user_id, target_date) index applies.
        if f.target_date_from is not None:
            stmt = stmt.where(Goal.target_date >= f.target_date_from)
        if f.target_date_before is not None:
            stmt = stmt.where(Goal.target_date < f.target_date_before)
        return stmt

    def get_for_user(self, goal_id: uuid.UUID, user_id: uuid.UUID) -> Goal | None:
        stmt = select(Goal).where(
            Goal.id == goal_id, Goal.user_id == user_id, Goal.deleted_at.is_(None)
        )
        return self._db.scalar(stmt)

    def due_for_completion(self, user_id: uuid.UUID, today: date) -> Sequence[Goal]:
        """Goals whose target date has arrived and that aren't `completed` yet.

        Rows are locked and already-locked rows skipped, so two concurrent requests can't
        both complete the same goal.
        """
        stmt = (
            select(Goal)
            .where(
                Goal.user_id == user_id,
                Goal.deleted_at.is_(None),
                Goal.target_date <= today,
                Goal.action != GoalAction.COMPLETED,
            )
            .with_for_update(of=Goal, skip_locked=True)
        )
        return self._db.scalars(stmt).all()

    def add(self, goal: Goal) -> Goal:
        self._db.add(goal)
        self._db.flush()
        return goal


class GoalLogRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def add(self, entry: GoalLog) -> None:
        self._db.add(entry)

    def latest_for_goal(self, goal_id: uuid.UUID) -> GoalLog | None:
        stmt = select(GoalLog).where(GoalLog.goal_id == goal_id).order_by(GoalLog.id.desc())
        return self._db.scalars(stmt.limit(1)).first()

    def list_for_goal(self, goal_id: uuid.UUID) -> Sequence[GoalLog]:
        stmt = select(GoalLog).where(GoalLog.goal_id == goal_id).order_by(GoalLog.id)
        return self._db.scalars(stmt).all()
