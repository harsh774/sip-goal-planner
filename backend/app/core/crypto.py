"""Encryption at rest for personal-data columns.

Ciphertext format: "v1:" + base64(nonce[12] || ciphertext || tag[16]), AES-256-GCM.
The version prefix leaves room for key rotation later.

Email lookup uses a separate keyed hash (HMAC-SHA256), so a unique index and
login can work without decrypting every row.
"""

import base64
import hashlib
import hmac
import os
from functools import lru_cache

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.core.config import get_settings

_PREFIX = "v1:"
_NONCE_BYTES = 12


class Crypto:
    def __init__(self, data_key: bytes, email_hash_key: bytes) -> None:
        self._aead = AESGCM(data_key)
        self._hash_key = email_hash_key

    def encrypt(self, plaintext: str) -> str:
        nonce = os.urandom(_NONCE_BYTES)
        sealed = self._aead.encrypt(nonce, plaintext.encode("utf-8"), None)
        return _PREFIX + base64.b64encode(nonce + sealed).decode("ascii")

    def decrypt(self, token: str) -> str:
        if not token.startswith(_PREFIX):
            raise ValueError("Unknown ciphertext version")
        blob = base64.b64decode(token[len(_PREFIX) :])
        nonce, sealed = blob[:_NONCE_BYTES], blob[_NONCE_BYTES:]
        return self._aead.decrypt(nonce, sealed, None).decode("utf-8")

    def email_hash(self, email: str) -> str:
        normalised = normalise_email(email).encode("utf-8")
        return hmac.new(self._hash_key, normalised, hashlib.sha256).hexdigest()


def normalise_email(email: str) -> str:
    return email.strip().lower()


@lru_cache
def get_crypto() -> Crypto:
    settings = get_settings()
    return Crypto(settings.data_key_bytes, settings.email_hash_key_bytes)
