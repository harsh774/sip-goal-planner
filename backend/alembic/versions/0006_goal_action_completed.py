"""Add 'completed' to goal_action, and goals.action: the latest history action per goal.

Revision ID: 0006
Revises: 0005
Create Date: 2026-11-21
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TYPE goal_action ADD VALUE IF NOT EXISTS 'completed'")
    op.add_column(
        "goals",
        sa.Column(
            "action",
            postgresql.ENUM(name="goal_action", create_type=False),
            nullable=False,
            server_default=sa.text("'created'"),
        ),
    )
    # Backfill from each goal's newest history row (UUIDv7 ids sort by time).
    op.execute(
        """
        UPDATE goals SET action = latest.action
        FROM (
            SELECT DISTINCT ON (goal_id) goal_id, action
            FROM goal_logs ORDER BY goal_id, id DESC
        ) AS latest
        WHERE latest.goal_id = goals.id
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE goals DROP COLUMN IF EXISTS action")
    # PostgreSQL can't drop an enum value: drop the rows that use it, then rebuild the type.
    op.execute("DELETE FROM goal_logs WHERE action = 'completed'")
    op.execute("ALTER TYPE goal_action RENAME TO goal_action_old")
    op.execute("CREATE TYPE goal_action AS ENUM ('created', 'updated', 'deleted')")
    op.execute(
        "ALTER TABLE goal_logs ALTER COLUMN action TYPE goal_action USING action::text::goal_action"
    )
    op.execute("DROP TYPE goal_action_old")
