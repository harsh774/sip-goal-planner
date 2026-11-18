from datetime import UTC, datetime, timedelta
from functools import lru_cache

from cryptography.hazmat.primitives.asymmetric import rsa
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.transport_crypto import load_private_key, new_key_pair
from app.models import TransportKey
from app.models.enums import TransportKeyStatus


class UnknownClient(Exception):
    pass


class StaleKey(Exception):
    """The key version is unknown, revoked, or past its grace period."""


class TransportKeyService:
    def __init__(self, db: Session) -> None:
        self._db = db
        self._settings = get_settings()

    def _check_client(self, client_id: str) -> None:
        if client_id not in self._settings.transport_client_id_list:
            raise UnknownClient(client_id)

    def active(self, client_id: str) -> TransportKey:
        """The client's active key, created on first use."""
        self._check_client(client_id)
        if key := self._active(client_id):
            return key
        try:
            # After the active key was revoked, earlier versions exist: continue after them.
            return self._create(client_id, version=self._latest_version(client_id) + 1)
        except IntegrityError:
            # Another request created it first.
            self._db.rollback()
            if key := self._active(client_id):
                return key
            raise

    def rotate(self, client_id: str) -> TransportKey:
        """New active version; the previous one is retired and still accepted for a while."""
        self._check_client(client_id)
        latest = self._latest_version(client_id)
        if current := self._active(client_id):
            current.status = TransportKeyStatus.RETIRED
            current.retired_at = datetime.now(UTC)
            self._db.flush()
        # Two rotations at once collide on the unique version; rotation is an operator CLI.
        return self._create(client_id, version=latest + 1)

    def revoke(self, client_id: str, version: int) -> None:
        """Stop accepting a version now. Revoking the active key means the next public-key
        request issues a new version."""
        self._check_client(client_id)
        key = self._get(client_id, version)
        if key is None:
            raise StaleKey(version)
        key.status = TransportKeyStatus.REVOKED
        self._db.commit()

    def private_key(self, client_id: str, version: int) -> rsa.RSAPrivateKey:
        """The private key for a version a client may still use."""
        self._check_client(client_id)
        key = self._get(client_id, version)
        if key is None or key.status == TransportKeyStatus.REVOKED:
            raise StaleKey(version)
        if key.status == TransportKeyStatus.RETIRED:
            grace = timedelta(hours=self._settings.transport_key_grace_hours)
            if key.retired_at is None or datetime.now(UTC) - key.retired_at > grace:
                raise StaleKey(version)
        return _parsed(key.id.hex, key.private_key)

    def _latest_version(self, client_id: str) -> int:
        return (
            self._db.scalar(
                select(func.max(TransportKey.version)).where(TransportKey.client_id == client_id)
            )
            or 0
        )

    def _active(self, client_id: str) -> TransportKey | None:
        return self._db.scalar(
            select(TransportKey).where(
                TransportKey.client_id == client_id,
                TransportKey.status == TransportKeyStatus.ACTIVE,
            )
        )

    def _get(self, client_id: str, version: int) -> TransportKey | None:
        return self._db.scalar(
            select(TransportKey).where(
                TransportKey.client_id == client_id, TransportKey.version == version
            )
        )

    def _create(self, client_id: str, version: int) -> TransportKey:
        public, private = new_key_pair()
        key = TransportKey(
            client_id=client_id,
            version=version,
            public_key=public,
            private_key=private,
            status=TransportKeyStatus.ACTIVE,
        )
        self._db.add(key)
        self._db.commit()
        return key


@lru_cache(maxsize=32)
def _parsed(key_id: str, pem: str) -> rsa.RSAPrivateKey:
    # Parsing a PEM is slow; status is still checked on every request above.
    return load_private_key(pem)
