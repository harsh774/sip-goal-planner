import uuid

import pytest
from sqlalchemy import text

from app.db.session import engine
from tests.conftest import API, auth_headers, goal_payload


def _create(client, headers, **overrides) -> dict:
    response = client.post(f"{API}/goals", json=goal_payload(**overrides), headers=headers)
    assert response.status_code == 201, response.json()
    return response.json()


def _codes(response) -> set[tuple[str, str]]:
    return {(e["field"], e["code"]) for e in response.json()["detail"]}


def test_create_returns_strings_and_stores_scaled_integers(client):
    headers = auth_headers(client)
    goal = _create(client, headers, current_corpus="20000.5", expected_return_pct="12.25")

    assert goal["current_corpus"] == "20000.50"
    assert goal["expected_return_pct"] == "12.25"
    assert goal["currency"] == "INR"
    with engine.connect() as conn:
        row = conn.execute(
            text("SELECT current_corpus, expected_return_bp FROM goals WHERE id = :id"),
            {"id": goal["id"]},
        ).one()
    assert tuple(row) == (2000050, 1225)


def test_validation_errors_carry_field_codes(client):
    headers = auth_headers(client)
    response = client.post(
        f"{API}/goals",
        json=goal_payload(
            target_amount="-5",
            target_date="2020-01-01",
            expected_return_pct="31",
            current_corpus="1.234",
            goal_type="boat",
        ),
        headers=headers,
    )

    assert response.status_code == 422
    assert _codes(response) == {
        ("target_amount", "amount_positive"),
        ("target_date", "date_past"),
        ("expected_return_pct", "return_range"),
        ("current_corpus", "too_many_decimals"),
        ("goal_type", "goal_type_invalid"),
    }


def test_jpy_amounts_cannot_have_decimals(client):
    headers = auth_headers(client)
    response = client.post(
        f"{API}/goals", json=goal_payload(currency="JPY", target_amount="100.50"), headers=headers
    )

    assert response.status_code == 422
    assert _codes(response) == {("target_amount", "too_many_decimals")}


def test_currency_is_locked_after_creation(client):
    headers = auth_headers(client)
    goal = _create(client, headers)

    response = client.patch(f"{API}/goals/{goal['id']}", json={"currency": "USD"}, headers=headers)

    assert response.status_code == 422
    assert _codes(response) == {("currency", "currency_locked")}


def test_new_goal_uses_the_users_default_currency(client):
    headers = auth_headers(client)
    client.patch(f"{API}/auth/me", json={"default_currency": "USD"}, headers=headers)

    assert _create(client, headers)["currency"] == "USD"


@pytest.mark.parametrize("suffix", ["", "/history", "/projection"])
def test_other_users_goals_are_not_found(client, suffix):
    owner = auth_headers(client, "owner@example.com")
    intruder = auth_headers(client, "intruder@example.com")
    goal = _create(client, owner)

    assert client.get(f"{API}/goals/{goal['id']}{suffix}", headers=intruder).status_code == 404
    assert client.get(f"{API}/goals", headers=intruder).json()["total"] == 0


def test_other_users_goals_cannot_be_changed(client):
    owner = auth_headers(client, "owner@example.com")
    intruder = auth_headers(client, "intruder@example.com")
    goal_id = _create(client, owner)["id"]

    patch = client.patch(f"{API}/goals/{goal_id}", json={"name": "Mine"}, headers=intruder)
    delete = client.delete(f"{API}/goals/{goal_id}", headers=intruder)

    assert (patch.status_code, delete.status_code) == (404, 404)
    assert (
        client.get(f"{API}/goals/{goal_id}", headers=owner).json()["name"] == goal_payload()["name"]
    )


def test_personal_data_is_encrypted_at_rest(client):
    headers = auth_headers(client, "secret.person@example.com")
    _create(client, headers, name="Aanya's college fund")

    with engine.connect() as conn:
        email = conn.execute(text("SELECT email FROM users")).scalar_one()
        name = conn.execute(text("SELECT name FROM goals")).scalar_one()
        changes = conn.execute(text("SELECT changes FROM goal_logs")).scalar_one()

    for stored in (email, name, changes):
        assert stored.startswith("v1:")
    assert "secret.person" not in email
    assert "Aanya" not in name and "Aanya" not in changes
    assert client.get(f"{API}/goals", headers=headers).json()["items"][0]["name"] == (
        "Aanya's college fund"
    )


def test_history_records_create_and_only_changed_fields(client):
    headers = auth_headers(client)
    goal_id = _create(client, headers)["id"]

    client.patch(
        f"{API}/goals/{goal_id}",
        json={"current_corpus": "50000", "inflation_pct": "7", "name": goal_payload()["name"]},
        headers=headers,
    )
    client.patch(f"{API}/goals/{goal_id}", json={"current_corpus": "50000.00"}, headers=headers)

    history = client.get(f"{API}/goals/{goal_id}/history", headers=headers).json()
    assert [entry["action"] for entry in history] == ["created", "updated"]
    assert history[0]["changes"]["target_amount"] == "10000000.00"
    assert history[1]["changes"] == {
        "current_corpus": {"old": "20000.00", "new": "50000.00"},
        "inflation_pct": {"old": "6.00", "new": "7.00"},
    }


def test_delete_is_soft_and_logged(client):
    headers = auth_headers(client)
    goal_id = _create(client, headers)["id"]

    assert client.delete(f"{API}/goals/{goal_id}", headers=headers).status_code == 204
    assert client.get(f"{API}/goals/{goal_id}", headers=headers).status_code == 404
    assert client.get(f"{API}/goals", headers=headers).json()["items"] == []

    with engine.connect() as conn:
        deleted_at = conn.execute(
            text("SELECT deleted_at FROM goals WHERE id = :id"), {"id": goal_id}
        ).scalar_one()
        actions = (
            conn.execute(
                text("SELECT action FROM goal_logs WHERE goal_id = :id ORDER BY id"),
                {"id": goal_id},
            )
            .scalars()
            .all()
        )
    assert deleted_at is not None
    assert actions == ["created", "deleted"]


def test_ids_are_time_ordered_uuid7(client):
    headers = auth_headers(client)
    ids = [_create(client, headers, name=f"Goal {n}")["id"] for n in range(3)]

    assert all(uuid.UUID(i).version == 7 for i in ids)
    listed = [g["id"] for g in client.get(f"{API}/goals", headers=headers).json()["items"]]
    assert listed == list(reversed(ids))


def test_projection_endpoint_matches_worked_example(client):
    headers = auth_headers(client)
    goal_id = _create(client, headers)["id"]

    body = client.get(
        f"{API}/goals/{goal_id}/projection", params={"as_of": "2026-11-18"}, headers=headers
    ).json()

    assert body["months"] == 144
    assert body["level"]["first_year_sip"] == "32205.00"
    assert body["step_up"]["first_year_sip"] == "20519.00"
    assert body["today_value"] == "4969693.64"
    assert len(body["level"]["rows"]) == 12
    assert "illustrative" in body["assumptions_note"]


def test_inflation_defaults_to_two_percent(client):
    headers = auth_headers(client)
    payload = goal_payload()
    del payload["inflation_pct"]

    created = client.post(f"{API}/goals", json=payload, headers=headers)

    assert created.status_code == 201
    assert created.json()["inflation_pct"] == "2.00"
