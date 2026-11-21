import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column
from uuid6 import uuid7

from app.db.base import Base
from app.db.types import EncryptedJSON
from app.models.enums import GoalAction, goal_action_enum


class GoalLog(Base):
    """Append-only history of a goal. Written in the same transaction as the change.

    `changes`:
      created / deleted -> full snapshot {field: value}
      updated           -> only changed fields {field: {"old": ..., "new": ...}}
      completed         -> the plan that reached the target {plan_from, target_date, ...}
    Values use the API's string form. Encrypted at rest (contains goal names).
    """

    __tablename__ = "goal_logs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid7)
    goal_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("goals.id", ondelete="RESTRICT", name="fk_goal_logs_goal_id"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="RESTRICT", name="fk_goal_logs_user_id"),
        nullable=False,
    )
    action: Mapped[GoalAction] = mapped_column(goal_action_enum, nullable=False)
    changes: Mapped[dict[str, Any]] = mapped_column(EncryptedJSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
