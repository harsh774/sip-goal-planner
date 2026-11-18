"""Make users.last_name optional.

Revision ID: 0003
Revises: 0002
Create Date: 2026-11-19
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

from app.core.crypto import get_crypto

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("users", "last_name", nullable=True)


def downgrade() -> None:
    op.get_bind().execute(
        sa.text("UPDATE users SET last_name = :empty WHERE last_name IS NULL"),
        {"empty": get_crypto().encrypt("")},
    )
    op.alter_column("users", "last_name", nullable=False)
