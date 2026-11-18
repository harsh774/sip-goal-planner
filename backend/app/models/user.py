import uuid
from datetime import datetime

from sqlalchemy import DateTime, Text, UniqueConstraint, Uuid, func, text
from sqlalchemy.orm import Mapped, mapped_column
from uuid6 import uuid7

from app.db.base import Base
from app.db.types import EncryptedText
from app.models.enums import Currency, currency_enum


class User(Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("email_hash", name="uq_users_email_hash"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid7)
    email: Mapped[str] = mapped_column(EncryptedText, nullable=False)
    # Keyed hash of the normalised email: lookup and uniqueness without decrypting.
    email_hash: Mapped[str] = mapped_column(Text, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    display_name: Mapped[str] = mapped_column(EncryptedText, nullable=False)
    default_currency: Mapped[Currency] = mapped_column(
        currency_enum, nullable=False, server_default=text("'INR'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
