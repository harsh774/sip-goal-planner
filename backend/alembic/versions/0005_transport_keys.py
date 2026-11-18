"""Versioned RSA keys for encrypted request/response payloads.

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-19
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

status_enum = postgresql.ENUM("active", "retired", "revoked", name="transport_key_status")


def upgrade() -> None:
    status_enum.create(op.get_bind())
    op.create_table(
        "transport_keys",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("client_id", sa.Text(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("public_key", sa.Text(), nullable=False),
        sa.Column("private_key", sa.Text(), nullable=False),
        sa.Column(
            "status",
            postgresql.ENUM(name="transport_key_status", create_type=False),
            nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("retired_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("client_id", "version", name="uq_transport_keys_client_version"),
    )
    op.create_index(
        "uq_transport_keys_one_active",
        "transport_keys",
        ["client_id"],
        unique=True,
        postgresql_where=sa.text("status = 'active'"),
    )


def downgrade() -> None:
    op.drop_index("uq_transport_keys_one_active", table_name="transport_keys")
    op.drop_table("transport_keys")
    status_enum.drop(op.get_bind())
