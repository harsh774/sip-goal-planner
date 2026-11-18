import base64
import os
from collections.abc import Iterator
from pathlib import Path

import pytest

os.environ["DATABASE_URL"] = os.environ.get(
    "TEST_DATABASE_URL", "postgresql+psycopg://sip:sip@localhost:5433/sip_test"
)
os.environ["JWT_SECRET"] = "test-jwt-secret-that-is-32-bytes!"
os.environ["DATA_ENCRYPTION_KEY"] = base64.b64encode(b"d" * 32).decode()
os.environ["EMAIL_HASH_KEY"] = base64.b64encode(b"h" * 32).decode()

from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app.db.session import engine  # noqa: E402
from app.main import app  # noqa: E402

BACKEND_DIR = Path(__file__).resolve().parents[1]
API = "/api/v1"


@pytest.fixture(scope="session")
def migrated_db() -> None:
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    command.downgrade(config, "base")
    command.upgrade(config, "head")


@pytest.fixture
def client(migrated_db) -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE goal_logs, goals, users, transport_keys"))


def auth_headers(client: TestClient, email: str = "priya@example.com") -> dict[str, str]:
    password = "secret123"
    client.post(f"{API}/auth/register", json=register_payload(email=email, password=password))
    response = client.post(f"{API}/auth/login", data={"username": email, "password": password})
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def register_payload(**overrides) -> dict:
    payload = {
        "first_name": "Priya",
        "last_name": "Sharma",
        "email": "priya@example.com",
        "password": "secret123",
    }
    return payload | overrides


def goal_payload(**overrides) -> dict:
    payload = {
        "name": "Daughter's education",
        "goal_type": "education",
        "target_amount": "10000000.00",
        "target_date": "2038-11-18",
        "current_corpus": "20000.00",
        "expected_return_pct": "12",
        "annual_step_up_pct": "10",
        "inflation_pct": "6",
    }
    return payload | overrides
