import json
import os
from urllib.parse import urlencode

from sqlalchemy import text

from app.core.transport_crypto import (
    open_sealed,
    request_aad,
    response_aad,
    seal,
    wrap_key,
)
from app.db.session import SessionLocal, engine
from app.services.transport_keys import TransportKeyService
from tests.conftest import API, auth_headers, goal_payload


def _public_key(client, client_id="web"):
    return client.get(f"{API}/crypto/public-key", params={"client_id": client_id}).json()


def _encrypted(client, method, path, key, *, body=None, form=None, query=None, headers=None):
    """Sends a request the way the app does; returns (response, decrypted body or None)."""
    aes = os.urandom(32)
    full_path = f"{API}{path}"
    h = {
        "X-Enc-Client": key["client_id"],
        "X-Enc-Key-Version": str(key["key_version"]),
        "X-Enc-Key": wrap_key(key["public_key"], aes),
        **(headers or {}),
    }
    content = None
    if body is not None or form is not None:
        raw = json.dumps(body).encode() if body is not None else urlencode(form).encode()
        h["X-Enc-Content-Type"] = (
            "application/json" if body is not None else "application/x-www-form-urlencoded"
        )
        content = seal(aes, raw, request_aad(method, full_path))
    if query:
        sealed_q = seal(aes, urlencode(query).encode(), request_aad(method, full_path) + b"?")
        h["X-Enc-Query"] = sealed_q.decode()
    response = client.request(method, full_path, content=content, headers=h)
    plain = None
    if "x-enc-content-type" in response.headers:
        plain = json.loads(open_sealed(aes, response.content, response_aad(method, full_path)))
    return response, plain


def test_public_key_is_versioned_per_client_and_stable(client):
    first = _public_key(client)
    again = _public_key(client)

    assert first["key_version"] == 1 and first == again
    assert first["algorithm"] == "RSA-OAEP-SHA256+AES-256-GCM"
    assert _public_key(client, "android")["public_key"] != first["public_key"]
    unknown = client.get(f"{API}/crypto/public-key", params={"client_id": "nope"})
    assert unknown.status_code == 404


def test_full_flow_is_encrypted_both_ways(client):
    key = _public_key(client)
    _encrypted(
        client,
        "POST",
        "/auth/register",
        key,
        body={"first_name": "Asha", "email": "asha@example.com", "password": "secret123"},
    )
    login, token = _encrypted(
        client,
        "POST",
        "/auth/login",
        key,
        form={"username": "asha@example.com", "password": "secret123"},
    )
    auth = {"Authorization": f"Bearer {token['access_token']}"}
    created, goal = _encrypted(client, "POST", "/goals", key, body=goal_payload(), headers=auth)
    listed, page = _encrypted(client, "GET", "/goals", key, query={"q": "education"}, headers=auth)

    assert login.status_code == 200 and created.status_code == 201
    assert b"Daughter" not in created.content  # the wire carries ciphertext only
    assert goal["name"] == "Daughter's education"
    assert [g["id"] for g in page["items"]] == [goal["id"]]


def test_errors_come_back_encrypted_too(client):
    key = _public_key(client)
    response, body = _encrypted(
        client, "POST", "/auth/login", key, form={"username": "x@example.com", "password": "x"}
    )

    assert response.status_code == 401
    assert body == {"detail": "Incorrect email or password."}


def test_tampered_or_replayed_payload_is_rejected(client):
    key = _public_key(client)
    aes = os.urandom(32)
    sealed = seal(aes, b"{}", request_aad("POST", f"{API}/auth/register"))
    response = client.post(
        f"{API}/goals",  # sealed for /auth/register, sent to /goals
        content=sealed,
        headers={
            "X-Enc-Client": "web",
            "X-Enc-Key-Version": str(key["key_version"]),
            "X-Enc-Key": wrap_key(key["public_key"], aes),
            "X-Enc-Content-Type": "application/json",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"][0]["code"] == "encryption_invalid"


def test_rotation_keeps_retired_keys_for_the_grace_period_then_revoked_ones_fail(client):
    old = _public_key(client)
    with SessionLocal() as db:
        TransportKeyService(db).rotate("web")
    new = _public_key(client)

    still_ok, _ = _encrypted(client, "GET", "/goals", old, headers=auth_headers(client))
    with SessionLocal() as db:
        TransportKeyService(db).revoke("web", old["key_version"])
    rejected, _ = _encrypted(client, "GET", "/goals", old)

    assert new["key_version"] == old["key_version"] + 1
    assert still_ok.status_code == 200
    assert rejected.status_code == 409
    assert rejected.json()["detail"][0]["code"] == "key_version_stale"


def test_private_keys_are_encrypted_at_rest(client):
    _public_key(client)
    with engine.connect() as conn:
        stored = conn.execute(text("SELECT private_key FROM transport_keys")).scalar_one()
    assert stored.startswith("v1:") and "PRIVATE KEY" not in stored


def test_plain_requests_still_work(client):
    assert client.get(f"{API}/goals", headers=auth_headers(client)).status_code == 200
