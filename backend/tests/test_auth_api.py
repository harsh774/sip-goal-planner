from sqlalchemy import text

from app.db.session import engine
from tests.conftest import API, auth_headers, register_payload


def test_register_login_and_me(client):
    response = client.post(f"{API}/auth/register", json=register_payload(email="Priya@Example.com"))
    assert response.status_code == 201
    assert response.json()["email"] == "priya@example.com"
    assert response.json()["default_currency"] == "INR"

    login = client.post(
        f"{API}/auth/login", data={"username": "PRIYA@example.com", "password": "secret123"}
    )
    assert login.status_code == 200
    token = login.json()["access_token"]

    me = client.get(f"{API}/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert (me.json()["first_name"], me.json()["last_name"]) == ("Priya", "Sharma")


def test_duplicate_email_is_rejected_case_insensitively(client):
    client.post(f"{API}/auth/register", json=register_payload(email="a@example.com"))
    response = client.post(f"{API}/auth/register", json=register_payload(email="A@EXAMPLE.com"))

    assert response.status_code == 409
    assert response.json()["detail"][0]["code"] == "email_taken"


def test_weak_password_and_bad_email(client):
    response = client.post(
        f"{API}/auth/register",
        json=register_payload(email="nope", password="short", first_name=" ", last_name="x" * 51),
    )

    assert response.status_code == 422
    codes = {(e["field"], e["code"]) for e in response.json()["detail"]}
    assert codes == {
        ("email", "email_invalid"),
        ("password", "password_weak"),
        ("first_name", "name_required"),
        ("last_name", "name_too_long"),
    }


def test_wrong_password_is_401(client):
    auth_headers(client)
    response = client.post(
        f"{API}/auth/login", data={"username": "priya@example.com", "password": "wrong123"}
    )
    assert response.status_code == 401


def test_goals_require_a_valid_token(client):
    assert client.get(f"{API}/goals").status_code == 401
    bad = client.get(f"{API}/goals", headers={"Authorization": "Bearer not-a-token"})
    assert bad.status_code == 401


def test_update_default_currency(client):
    headers = auth_headers(client)

    ok = client.patch(f"{API}/auth/me", json={"default_currency": "EUR"}, headers=headers)
    bad = client.patch(f"{API}/auth/me", json={"default_currency": "XYZ"}, headers=headers)

    assert ok.json()["default_currency"] == "EUR"
    assert bad.status_code == 422
    assert bad.json()["detail"][0]["code"] == "currency_invalid"


def test_names_are_encrypted_and_editable(client):
    headers = auth_headers(client)

    updated = client.patch(f"{API}/auth/me", json={"last_name": "Verma"}, headers=headers).json()

    assert (updated["first_name"], updated["last_name"]) == ("Priya", "Verma")
    with engine.connect() as conn:
        first, last = conn.execute(text("SELECT first_name, last_name FROM users")).one()
    assert first.startswith("v1:") and last.startswith("v1:")
