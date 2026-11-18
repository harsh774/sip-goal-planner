"""Print fresh secrets in .env format: python3 scripts/generate_secrets.py >> .env"""

import base64
import os


def _key() -> str:
    return base64.b64encode(os.urandom(32)).decode("ascii")


if __name__ == "__main__":
    print(f"JWT_SECRET={_key()}")
    print(f"DATA_ENCRYPTION_KEY={_key()}")
    print(f"EMAIL_HASH_KEY={_key()}")
