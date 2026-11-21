from sqlalchemy import text

from app.db.session import engine
from tests.conftest import API, auth_headers, goal_payload


def _create(client, headers, **overrides) -> dict:
    response = client.post(f"{API}/goals", json=goal_payload(**overrides), headers=headers)
    assert response.status_code == 201, response.json()
    return response.json()


def _move_target_date(goal_id: str, target_date: str) -> None:
    # The API only accepts future dates, so a passed deadline is set directly.
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE goals SET target_date = :d WHERE id = :id"),
            {"d": target_date, "id": goal_id},
        )


def _list(client, headers) -> dict[str, dict]:
    response = client.get(f"{API}/goals", headers=headers)
    assert response.status_code == 200, response.json()
    return {g["id"]: g for g in response.json()["items"]}


def _actions(client, headers, goal_id: str) -> list[str]:
    response = client.get(f"{API}/goals/{goal_id}/history", headers=headers)
    return [entry["action"] for entry in response.json()]


def test_new_goal_reports_created(client):
    headers = auth_headers(client)
    goal = _create(client, headers)
    assert goal["action"] == "created"


def test_goal_past_its_target_date_is_completed_once(client):
    headers = auth_headers(client)
    goal = _create(client, headers)
    _move_target_date(goal["id"], "2020-01-01")

    assert _list(client, headers)[goal["id"]]["action"] == "completed"
    _list(client, headers)  # a second read must not log it again
    assert _actions(client, headers, goal["id"]) == ["created", "completed"]

    completed = client.get(f"{API}/goals/{goal['id']}/history", headers=headers).json()[-1]
    assert completed["changes"]["target_amount"] == "10000000.00"
    assert float(completed["changes"]["final_balance"]) >= 10_000_000


def test_goal_with_future_target_date_stays_open(client):
    headers = auth_headers(client)
    goal = _create(client, headers)

    assert _list(client, headers)[goal["id"]]["action"] == "created"
    assert _actions(client, headers, goal["id"]) == ["created"]


def test_goal_due_today_is_completed(client):
    headers = auth_headers(client)
    goal = _create(client, headers)
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE goals SET target_date = CURRENT_DATE WHERE id = :id"), {"id": goal["id"]}
        )

    assert _list(client, headers)[goal["id"]]["action"] == "completed"


def test_deleted_goal_is_not_completed(client):
    headers = auth_headers(client)
    goal = _create(client, headers)
    _move_target_date(goal["id"], "2020-01-01")
    client.delete(f"{API}/goals/{goal['id']}", headers=headers)

    _list(client, headers)
    with engine.connect() as conn:
        actions = conn.execute(
            text("SELECT action FROM goal_logs WHERE goal_id = :id ORDER BY id"),
            {"id": goal["id"]},
        ).scalars()
        assert list(actions) == ["created", "deleted"]


def test_only_the_owners_due_goals_are_completed(client):
    owner = auth_headers(client)
    other = auth_headers(client, email="rahul@example.com")
    goal = _create(client, owner)
    _move_target_date(goal["id"], "2020-01-01")

    _list(client, other)
    assert _actions(client, owner, goal["id"]) == ["created"]


def test_action_column_follows_every_write(client):
    headers = auth_headers(client)
    goal = _create(client, headers)

    edited = client.patch(f"{API}/goals/{goal['id']}", json={"name": "Car"}, headers=headers)
    assert edited.json()["action"] == "updated"

    client.delete(f"{API}/goals/{goal['id']}", headers=headers)
    with engine.connect() as conn:
        action = conn.execute(
            text("SELECT action FROM goals WHERE id = :id"), {"id": goal["id"]}
        ).scalar_one()
    assert action == "deleted"


def test_exclude_completed_leaves_completed_goals_out(client):
    headers = auth_headers(client)
    done = _create(client, headers, name="Done")
    open_goal = _create(client, headers, name="Open")
    _move_target_date(done["id"], "2020-01-01")
    _list(client, headers)

    response = client.get(
        f"{API}/goals",
        params={"sort": "target_date", "exclude_completed": "true"},
        headers=headers,
    )
    body = response.json()
    assert [g["id"] for g in body["items"]] == [open_goal["id"]]
    assert body["total"] == 1
