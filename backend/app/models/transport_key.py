import uuid
from datetime import datetime

from sqlalchemy import DateTime, Index, Integer, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column
from uuid6 import uuid7

from app.db.base import Base
from app.db.types import EncryptedText
from app.models.enums import TransportKeyStatus, transport_key_status_enum


class TransportKey(Base):
    """An RSA key pair a client uses to wrap its per-request AES key. Versioned per client."""

    __tablename__ = "transport_keys"
    __table_args__ = (
        UniqueConstraint("client_id", "version", name="uq_transport_keys_client_version"),
        # At most one active key per client.
        Index(
            "uq_transport_keys_one_active",
            "client_id",
            unique=True,
            postgresql_where=text("status = 'active'"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid7)
    client_id: Mapped[str] = mapped_column(Text, nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    public_key: Mapped[str] = mapped_column(Text, nullable=False)
    # PKCS#8 PEM, encrypted at rest like other secrets.
    private_key: Mapped[str] = mapped_column(EncryptedText, nullable=False)
    status: Mapped[TransportKeyStatus] = mapped_column(transport_key_status_enum, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    retired_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
