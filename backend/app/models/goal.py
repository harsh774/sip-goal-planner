import uuid
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column
from uuid6 import uuid7

from app.db.base import Base
from app.db.types import EncryptedText
from app.models.enums import (
    Currency,
    GoalAction,
    GoalType,
    currency_enum,
    goal_action_enum,
    goal_type_enum,
)


class Goal(Base):
    """A savings goal.

    Money columns hold hundredths of the goal's currency unit (₹1,234.50 -> 123450).
    Rate columns hold basis points (12.5% -> 1250).
    """

    __tablename__ = "goals"
    __table_args__ = (
        CheckConstraint("target_amount > 0", name="ck_goals_target_amount_positive"),
        CheckConstraint("current_corpus >= 0", name="ck_goals_current_corpus_non_negative"),
        CheckConstraint(
            "expected_return_bp BETWEEN 0 AND 3000", name="ck_goals_expected_return_bp_range"
        ),
        CheckConstraint(
            "annual_step_up_bp BETWEEN 0 AND 2500", name="ck_goals_annual_step_up_bp_range"
        ),
        CheckConstraint("inflation_bp BETWEEN 0 AND 1200", name="ck_goals_inflation_bp_range"),
        Index("ix_goals_user_id_deleted_at", "user_id", "deleted_at"),
        Index("ix_goals_user_id_target_date", "user_id", "target_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid7)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="RESTRICT", name="fk_goals_user_id"), nullable=False
    )
    name: Mapped[str] = mapped_column(EncryptedText, nullable=False)
    goal_type: Mapped[GoalType] = mapped_column(goal_type_enum, nullable=False)
    currency: Mapped[Currency] = mapped_column(currency_enum, nullable=False)
    target_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    target_date: Mapped[date] = mapped_column(Date, nullable=False)
    current_corpus: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("0")
    )
    expected_return_bp: Mapped[int] = mapped_column(BigInteger, nullable=False)
    annual_step_up_bp: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("0")
    )
    inflation_bp: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("200")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # The goal's latest history action, set with every goal_logs row in the same transaction.
    action: Mapped[GoalAction] = mapped_column(
        goal_action_enum,
        nullable=False,
        default=GoalAction.CREATED,
        server_default=text("'created'"),
    )
