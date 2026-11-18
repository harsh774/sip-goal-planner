from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel

from app.api.deps import DbSession
from app.core.transport_crypto import ALGORITHM
from app.services.transport_keys import TransportKeyService, UnknownClient

router = APIRouter(prefix="/crypto", tags=["crypto"])


class PublicKeyOut(BaseModel):
    client_id: str
    key_version: int
    algorithm: str
    public_key: str


@router.get("/public-key", response_model=PublicKeyOut)
def public_key(client_id: Annotated[str, Query(min_length=1, max_length=50)], db: DbSession):
    """The RSA public key (SPKI DER, base64) for an app version, used to wrap per-request
    AES keys. `client_id` is the app version from its pubspec.yaml, e.g. `1.0.0`.

    Public: a public key is safe to share. Send the returned `key_version` with each
    encrypted request; a `409 key_version_stale` means fetch this again.
    """
    try:
        key = TransportKeyService(db).active(client_id)
    except UnknownClient:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown client id.") from None
    return PublicKeyOut(
        client_id=key.client_id,
        key_version=key.version,
        algorithm=ALGORITHM,
        public_key=key.public_key,
    )
