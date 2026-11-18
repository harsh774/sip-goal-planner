import uuid
from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Goal, GoalLog


class GoalRepository:
    """Data access for goals. Every query is scoped to one user and skips soft-deleted rows."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_user(self, user_id: uuid.UUID) -> Sequence[Goal]:
        stmt = (
            select(Goal)
            .where(Goal.user_id == user_id, Goal.deleted_at.is_(None))
            .order_by(Goal.id.desc())
        )
        return self._db.scalars(stmt).all()

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
