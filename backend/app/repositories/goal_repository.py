import uuid
from collections.abc import Sequence

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.models import Goal, GoalLog
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
    ) -> tuple[Sequence[Goal], int]:
        stmt = self._matching(user_id, filters)
        total = self._db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        items = self._db.scalars(stmt.order_by(*_ORDER[sort]).offset(offset).limit(limit)).all()
        return items, total

    def all_matching(self, user_id: uuid.UUID, filters: GoalFilters) -> Sequence[Goal]:
        return self._db.scalars(self._matching(user_id, filters)).all()

    @staticmethod
    def _matching(user_id: uuid.UUID, f: GoalFilters) -> Select[tuple[Goal]]:
        stmt = select(Goal).where(Goal.user_id == user_id, Goal.deleted_at.is_(None))
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

    def add(self, goal: Goal) -> Goal:
        self._db.add(goal)
        self._db.flush()
        return goal


class GoalLogRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def add(self, entry: GoalLog) -> None:
        self._db.add(entry)

    def list_for_goal(self, goal_id: uuid.UUID) -> Sequence[GoalLog]:
        stmt = select(GoalLog).where(GoalLog.goal_id == goal_id).order_by(GoalLog.id)
        return self._db.scalars(stmt).all()
