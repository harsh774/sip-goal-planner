"""Initial schema: users, goals, goal_logs and their enum types.

Encrypted columns are plain `text` at the database level; encryption happens in the app.

Revision ID: 0001
Revises:
Create Date: 2026-11-18
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CURRENCIES = ("INR", "USD", "EUR", "GBP", "AED", "SGD", "AUD", "CAD", "JPY", "CNY", "BRL")
GOAL_TYPES = (
    "home",
    "education",
    "retirement",
    "car",
    "wedding",
    "travel",
    "emergency_fund",
    "other",
)
GOAL_ACTIONS = ("created", "updated", "deleted")

currency_code = postgresql.ENUM(*CURRENCIES, name="currency_code", create_type=False)
goal_type = postgresql.ENUM(*GOAL_TYPES, name="goal_type", create_type=False)
goal_action = postgresql.ENUM(*GOAL_ACTIONS, name="goal_action", create_type=False)


def upgrade() -> None:
    bind = op.get_bind()
    for enum_type in (currency_code, goal_type, goal_action):
        enum_type.create(bind, checkfirst=False)

    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("email", sa.Text(), nullable=False),
        sa.Column("email_hash", sa.Text(), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("display_name", sa.Text(), nullable=False),
        sa.Column(
            "default_currency", currency_code, nullable=False, server_default=sa.text("'INR'")
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.UniqueConstraint("email_hash", name="uq_users_email_hash"),
    )

    op.create_table(
        "goals",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="RESTRICT", name="fk_goals_user_id"),
            nullable=False,
        ),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("goal_type", goal_type, nullable=False),
        sa.Column("currency", currency_code, nullable=False),
        sa.Column("target_amount", sa.BigInteger(), nullable=False),
        sa.Column("target_date", sa.Date(), nullable=False),
        sa.Column("current_corpus", sa.BigInteger(), nullable=False, server_default=sa.text("0")),
        sa.Column("expected_return_bp", sa.BigInteger(), nullable=False),
        sa.Column(
            "annual_step_up_bp", sa.BigInteger(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column("inflation_bp", sa.BigInteger(), nullable=False, server_default=sa.text("600")),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("target_amount > 0", name="ck_goals_target_amount_positive"),
        sa.CheckConstraint("current_corpus >= 0", name="ck_goals_current_corpus_non_negative"),
        sa.CheckConstraint(
            "expected_return_bp BETWEEN 0 AND 3000", name="ck_goals_expected_return_bp_range"
        ),
        sa.CheckConstraint(
            "annual_step_up_bp BETWEEN 0 AND 2500", name="ck_goals_annual_step_up_bp_range"
        ),
        sa.CheckConstraint("inflation_bp BETWEEN 0 AND 1200", name="ck_goals_inflation_bp_range"),
    )
    op.create_index("ix_goals_user_id_deleted_at", "goals", ["user_id", "deleted_at"])

    op.create_table(
        "goal_logs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "goal_id",
            sa.Uuid(),
            sa.ForeignKey("goals.id", ondelete="RESTRICT", name="fk_goal_logs_goal_id"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="RESTRICT", name="fk_goal_logs_user_id"),
            nullable=False,
        ),
        sa.Column("action", goal_action, nullable=False),
        sa.Column("changes", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_goal_logs_goal_id", "goal_logs", ["goal_id"])


def downgrade() -> None:
    op.drop_index("ix_goal_logs_goal_id", table_name="goal_logs")
    op.drop_table("goal_logs")
    op.drop_index("ix_goals_user_id_deleted_at", table_name="goals")
    op.drop_table("goals")
    op.drop_table("users")
    bind = op.get_bind()
    for enum_type in (goal_action, goal_type, currency_code):
        enum_type.drop(bind, checkfirst=False)
