"""Decrypts encrypted requests and encrypts their responses (see app/core/transport_crypto).

A request opts in by sending these headers:
  X-Enc-Client        client id ("web", "android")
  X-Enc-Key-Version   version of the public key used
  X-Enc-Key           the per-request AES key, wrapped with that RSA public key
  X-Enc-Content-Type  the body's real content type (when there is a body)
  X-Enc-Query         the sealed query string (when there is one)
The body is the sealed payload. The response body is sealed with the same AES key,
and X-Enc-Content-Type gives its real content type. Requests without X-Enc-Key
pass through untouched, so Swagger and plain clients keep working.
"""

import binascii
from collections.abc import MutableMapping
from typing import Any

from cryptography.exceptions import InvalidTag
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import Headers, MutableHeaders
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.transport_crypto import (
    open_sealed,
    request_aad,
    response_aad,
    seal,
    unwrap_key,
)
from app.db.session import SessionLocal
from app.services.transport_keys import StaleKey, TransportKeyService, UnknownClient

EXPOSED_HEADERS = ["x-enc-content-type"]


def _error(status: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={"detail": [{"field": None, "code": code, "message": message}]},
    )


def _aes_key(client_id: str, version: int, wrapped: str) -> bytes:
    with SessionLocal() as db:
        private = TransportKeyService(db).private_key(client_id, version)
    return unwrap_key(private, wrapped)


class EncryptedTransportMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        headers = Headers(scope=scope)
        wrapped = headers.get("x-enc-key")
        if not wrapped:
            await self.app(scope, receive, send)
            return

        method, path = scope["method"], scope["path"]
        try:
            version = int(headers.get("x-enc-key-version", ""))
            aes_key = await run_in_threadpool(
                _aes_key, headers.get("x-enc-client", ""), version, wrapped
            )
            body = await _read_body(receive)
            plain_body = open_sealed(aes_key, body, request_aad(method, path)) if body else b""
            sealed_query = headers.get("x-enc-query")
            query = (
                open_sealed(aes_key, sealed_query, request_aad(method, path) + b"?")
                if sealed_query
                else scope["query_string"]
            )
        except UnknownClient:
            await _error(400, "client_unknown", "Unknown client id.")(scope, receive, send)
            return
        except StaleKey:
            await _error(409, "key_version_stale", "Fetch the current public key and retry.")(
                scope, receive, send
            )
            return
        except (ValueError, InvalidTag, binascii.Error):
            await _error(400, "encryption_invalid", "The encrypted request could not be read.")(
                scope, receive, send
            )
            return

        inner = dict(scope, query_string=query)
        inner_headers = MutableHeaders(scope=inner)
        inner_headers["content-type"] = headers.get("x-enc-content-type", "application/json")
        inner_headers["content-length"] = str(len(plain_body))
        for name in ("x-enc-key", "x-enc-key-version", "x-enc-client", "x-enc-query"):
            del inner_headers[name]

        delivered = False

        async def receive_plain() -> Message:
            nonlocal delivered
            if not delivered:
                delivered = True
                return {"type": "http.request", "body": plain_body, "more_body": False}
            return await receive()

        start: MutableMapping[str, Any] = {}
        chunks: list[bytes] = []

        async def send_sealed(message: Message) -> None:
            if message["type"] == "http.response.start":
                start.update(message)
                return
            if message["type"] != "http.response.body":
                await send(message)
                return
            chunks.append(message.get("body", b""))
            if message.get("more_body", False):
                return
            sealed = seal(aes_key, b"".join(chunks), response_aad(method, path))
            out = MutableHeaders(raw=list(start.get("headers", [])))
            out["x-enc-content-type"] = out.get("content-type", "application/octet-stream")
            out["content-type"] = "text/plain; charset=utf-8"
            out["content-length"] = str(len(sealed))
            await send({**start, "headers": out.raw})
            await send({"type": "http.response.body", "body": sealed, "more_body": False})

        await self.app(inner, receive_plain, send_sealed)


async def _read_body(receive: Receive) -> bytes:
    body, more = b"", True
    while more:
        message = await receive()
        body += message.get("body", b"")
        more = message.get("more_body", False)
    return body
