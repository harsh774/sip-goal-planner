"""Rotate (or revoke) a client's transport encryption key.

    uv run python scripts/rotate_transport_key.py 1.0.0            # new key; old one retired
    uv run python scripts/rotate_transport_key.py 1.0.0 --revoke 3 # stop accepting key v3 now

Retired keys keep working for TRANSPORT_KEY_GRACE_HOURS so in-flight clients aren't cut off.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.session import SessionLocal  # noqa: E402
from app.services.transport_keys import TransportKeyService  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("client_id")
    parser.add_argument("--revoke", type=int, metavar="VERSION")
    args = parser.parse_args()

    with SessionLocal() as db:
        service = TransportKeyService(db)
        if args.revoke is not None:
            service.revoke(args.client_id, args.revoke)
            print(f"Revoked {args.client_id} v{args.revoke}")
        else:
            key = service.rotate(args.client_id)
            print(f"{args.client_id} now on v{key.version}")


if __name__ == "__main__":
    main()
