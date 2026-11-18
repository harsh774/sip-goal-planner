import pytest

from app.services import fx
from tests.conftest import API, auth_headers, goal_payload


@pytest.fixture
def portfolio(client):
    """Five goals across currencies, types, amounts and years."""
    headers = auth_headers(client)
    specs = [
        ("Car", "car", "INR", "800000", "2028-06-01"),
        ("Home", "home", "INR", "2500000", "2031-03-01"),
        ("Education", "education", "INR", "10000000", "2038-11-18"),
        ("Holiday", "travel", "USD", "5000", "2027-12-01"),
        ("Retirement", "retirement", "USD", "1000000", "2051-01-01"),
    ]
    for name, goal_type, currency, amount, date in specs:
        response = client.post(
            f"{API}/goals",
            json=goal_payload(
                name=name,
                goal_type=goal_type,
                currency=currency,
                target_amount=amount,
                target_date=date,
            ),
            headers=headers,
        )
        assert response.status_code == 201
    return headers


def _names(response) -> list[str]:
    return [g["name"] for g in response.json()["items"]]


def test_pages_report_totals_and_slice_results(client, portfolio):
    first = client.get(f"{API}/goals", params={"page_size": 2}, headers=portfolio).json()
    last = client.get(f"{API}/goals", params={"page_size": 2, "page": 3}, headers=portfolio)

    assert (first["total"], first["total_pages"], len(first["items"])) == (5, 3, 2)
    assert _names(last) == ["Car"]


def test_reaching_soon_sorts_by_target_date(client, portfolio):
    response = client.get(
        f"{API}/goals", params={"sort": "target_date", "page_size": 3}, headers=portfolio
    )

    assert _names(response) == ["Holiday", "Car", "Home"]


@pytest.mark.parametrize(
    ("params", "expected"),
    [
        ({"currency": "USD"}, {"Holiday", "Retirement"}),
        ({"goal_type": "home"}, {"Home"}),
        ({"currency": "INR", "min_target_amount": "1000000"}, {"Home", "Education"}),
        ({"currency": "INR", "max_target_amount": "2500000"}, {"Car", "Home"}),
        ({"target_year_from": 2030, "target_year_to": 2040}, {"Home", "Education"}),
        ({"target_year_to": 2028}, {"Car", "Holiday"}),
        ({"currency": "USD", "target_year_from": 2050}, {"Retirement"}),
    ],
)
def test_filters(client, portfolio, params, expected):
    response = client.get(f"{API}/goals", params=params, headers=portfolio)

    assert set(_names(response)) == expected
    assert response.json()["total"] == len(expected)


@pytest.mark.parametrize(
    ("params", "code"),
    [
        ({"page_size": 101}, "less_than_equal"),
        ({"page": 0}, "greater_than_equal"),
        ({"currency": "XYZ"}, "currency_invalid"),
        ({"min_target_amount": "5", "max_target_amount": "1"}, "amount_range_invalid"),
        ({"target_year_from": 2040, "target_year_to": 2030}, "year_range_invalid"),
        ({"sort": "random"}, "enum"),
    ],
)
def test_invalid_query_parameters(client, portfolio, params, code):
    response = client.get(f"{API}/goals", params=params, headers=portfolio)

    assert response.status_code == 422
    assert code in {e["code"] for e in response.json()["detail"]}


def test_summary_converts_into_the_chosen_currency(client, portfolio):
    inr = client.get(
        f"{API}/goals/summary", params={"currency": "INR", "as_of": "2026-11-18"}, headers=portfolio
    ).json()
    everything_in_usd = client.get(
        f"{API}/goals/summary",
        params={"in_currency": "USD", "as_of": "2026-11-18"},
        headers=portfolio,
    ).json()

    assert (inr["count"], inr["currency"], inr["converted"]) == (3, "INR", False)
    assert everything_in_usd["count"] == 5
    assert everything_in_usd["converted"] is True
    assert everything_in_usd["rates_as_of"] == fx.RATES_AS_OF.isoformat()

    usd_only = client.get(
        f"{API}/goals/summary",
        params={"currency": "USD", "in_currency": "USD", "as_of": "2026-11-18"},
        headers=portfolio,
    ).json()
    expected = float(usd_only["total_monthly_sip"]) + fx.convert(
        float(inr["total_monthly_sip"]), fx.Currency.INR, fx.Currency.USD
    )
    assert float(everything_in_usd["total_monthly_sip"]) == pytest.approx(expected, abs=0.01)


def test_summary_defaults_to_the_users_currency(client):
    headers = auth_headers(client)
    client.patch(f"{API}/auth/me", json={"default_currency": "EUR"}, headers=headers)

    body = client.get(f"{API}/goals/summary", headers=headers).json()

    assert (body["count"], body["currency"], body["total_monthly_sip"]) == (0, "EUR", "0.00")
