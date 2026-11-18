"""Application settings, read from environment variables (and `.env` if present)."""

import base64
import binascii
from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def _decode_key(value: str, name: str) -> bytes:
    try:
        raw = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ValueError(f"{name} must be base64-encoded") from exc
    if len(raw) != 32:
        raise ValueError(f"{name} must decode to exactly 32 bytes")
    return raw


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://sip:sip@localhost:5433/sip"

    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    cors_origins: str = "http://localhost:3000"

    data_encryption_key: str
    email_hash_key: str

    # Clients that may ask for a transport public key, and how long a replaced key still works.
    transport_client_ids: str = "web,android"
    transport_key_grace_hours: int = 24

    @field_validator("jwt_secret")
    @classmethod
    def _check_jwt_secret(cls, v: str) -> str:
        if len(v.encode("utf-8")) < 32:
            raise ValueError("JWT_SECRET must be at least 32 bytes")
        return v

    @field_validator("data_encryption_key")
    @classmethod
    def _check_data_key(cls, v: str) -> str:
        _decode_key(v, "DATA_ENCRYPTION_KEY")
        return v

    @field_validator("email_hash_key")
    @classmethod
    def _check_hash_key(cls, v: str) -> str:
        _decode_key(v, "EMAIL_HASH_KEY")
        return v

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def transport_client_id_list(self) -> list[str]:
        return [c.strip() for c in self.transport_client_ids.split(",") if c.strip()]

    @property
    def data_key_bytes(self) -> bytes:
        return _decode_key(self.data_encryption_key, "DATA_ENCRYPTION_KEY")

    @property
    def email_hash_key_bytes(self) -> bytes:
        return _decode_key(self.email_hash_key, "EMAIL_HASH_KEY")


@lru_cache
def get_settings() -> Settings:
    return Settings()
