"""Hybrid encryption for request and response payloads.

The client makes a fresh AES-256 key per request and wraps it with the server's
RSA public key (RSA-OAEP, SHA-256). Payloads are sealed with AES-256-GCM as
base64(nonce[12] || ciphertext || tag[16]). The request's method and path are the
associated data (plus the status for responses), so a sealed payload can't be
moved to another endpoint or given another status. Paths are the raw, percent-encoded
request path as the client sent it.
"""

import base64
import os

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

RSA_BITS = 3072
NONCE_BYTES = 12
ALGORITHM = "RSA-OAEP-SHA256+AES-256-GCM"

_OAEP = padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=None)


def new_key_pair() -> tuple[str, str]:
    """(public SPKI DER as base64, private PKCS#8 PEM)."""
    private = rsa.generate_private_key(public_exponent=65537, key_size=RSA_BITS)
    public_der = private.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo
    )
    private_pem = private.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    return base64.b64encode(public_der).decode("ascii"), private_pem.decode("ascii")


def load_private_key(pem: str) -> rsa.RSAPrivateKey:
    key = serialization.load_pem_private_key(pem.encode("ascii"), password=None)
    if not isinstance(key, rsa.RSAPrivateKey):
        raise ValueError("Not an RSA key")
    return key


def unwrap_key(private: rsa.RSAPrivateKey, wrapped_b64: str) -> bytes:
    key = private.decrypt(base64.b64decode(wrapped_b64, validate=True), _OAEP)
    if len(key) != 32:
        raise ValueError("Wrapped key must be 32 bytes")
    return key


def wrap_key(public_spki_b64: str, aes_key: bytes) -> str:
    """Client side of the exchange; used by tests and tools."""
    public = serialization.load_der_public_key(base64.b64decode(public_spki_b64))
    if not isinstance(public, rsa.RSAPublicKey):
        raise ValueError("Not an RSA key")
    return base64.b64encode(public.encrypt(aes_key, _OAEP)).decode("ascii")


def seal(aes_key: bytes, plaintext: bytes, aad: bytes) -> bytes:
    nonce = os.urandom(NONCE_BYTES)
    return base64.b64encode(nonce + AESGCM(aes_key).encrypt(nonce, plaintext, aad))


def open_sealed(aes_key: bytes, sealed_b64: bytes | str, aad: bytes) -> bytes:
    blob = base64.b64decode(sealed_b64, validate=True)
    return AESGCM(aes_key).decrypt(blob[:NONCE_BYTES], blob[NONCE_BYTES:], aad)


def request_aad(method: str, path: str) -> bytes:
    return f"req:{method.upper()}:{path}".encode()


def response_aad(status: int, method: str, path: str) -> bytes:
    return f"res:{status}:{method.upper()}:{path}".encode()
