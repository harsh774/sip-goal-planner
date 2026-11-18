"""Column types that encrypt on write and decrypt on read.

The database column is plain `text` holding ciphertext; models and services
only ever see plaintext.
"""

import json
from typing import Any

from sqlalchemy import Text
from sqlalchemy.types import TypeDecorator

from app.core.crypto import get_crypto


class EncryptedText(TypeDecorator[str]):
    impl = Text
    cache_ok = True

    def process_bind_param(self, value: str | None, dialect: Any) -> str | None:
        return None if value is None else get_crypto().encrypt(value)

    def process_result_value(self, value: str | None, dialect: Any) -> str | None:
        return None if value is None else get_crypto().decrypt(value)


class EncryptedJSON(TypeDecorator[Any]):
    impl = Text
    cache_ok = True

    def process_bind_param(self, value: Any, dialect: Any) -> str | None:
        if value is None:
            return None
        return get_crypto().encrypt(json.dumps(value, separators=(",", ":"), sort_keys=True))

    def process_result_value(self, value: str | None, dialect: Any) -> Any:
        return None if value is None else json.loads(get_crypto().decrypt(value))
