"""Replace users.display_name with first_name and last_name; index goals by target date.

The name columns are encrypted in the app, so existing rows are backfilled here in
Python: decrypt display_name, split it, encrypt each part.

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-18
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

from app.core.crypto import get_crypto

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("first_name", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("last_name", sa.Text(), nullable=True))

    crypto = get_crypto()
    bind = op.get_bind()
    for user_id, display_name in bind.execute(sa.text("SELECT id, display_name FROM users")):
        first, _, last = crypto.decrypt(display_name).strip().partition(" ")
        bind.execute(
            sa.text("UPDATE users SET first_name = :f, last_name = :l WHERE id = :id"),
            {"f": crypto.encrypt(first), "l": crypto.encrypt(last.strip()), "id": user_id},
        )

    op.alter_column("users", "first_name", nullable=False)
    op.alter_column("users", "last_name", nullable=False)
    op.drop_column("users", "display_name")
    op.create_index("ix_goals_user_id_target_date", "goals", ["user_id", "target_date"])


def downgrade() -> None:
    op.drop_index("ix_goals_user_id_target_date", table_name="goals")
    op.add_column("users", sa.Column("display_name", sa.Text(), nullable=True))

    crypto = get_crypto()
    bind = op.get_bind()
    for user_id, first, last in bind.execute(
        sa.text("SELECT id, first_name, last_name FROM users")
    ):
        full = f"{crypto.decrypt(first)} {crypto.decrypt(last)}".strip()
        bind.execute(
            sa.text("UPDATE users SET display_name = :d WHERE id = :id"),
            {"d": crypto.encrypt(full), "id": user_id},
        )

    op.alter_column("users", "display_name", nullable=False)
    op.drop_column("users", "last_name")
    op.drop_column("users", "first_name")
