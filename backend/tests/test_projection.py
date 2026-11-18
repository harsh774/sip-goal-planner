import json
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from app.services.projection import (
    ProjectionInput,
    effective_monthly_rate,
    months_between,
    project,
    required_first_sip,
)

VECTORS = json.loads(
    (Path(__file__).resolve().parents[2] / "shared" / "projection_vectors.json").read_text()
)["cases"]


def _inputs(raw: dict) -> ProjectionInput:
    return ProjectionInput(
        target=float(raw["target_amount"]),
        corpus=float(raw["current_corpus"]),
        annual_return=float(raw["expected_return_pct"]) / 100,
        annual_step_up=float(raw["annual_step_up_pct"]) / 100,
        inflation=float(raw["inflation_pct"]) / 100,
        as_of=date.fromisoformat(raw["as_of"]),
        target_date=date.fromisoformat(raw["target_date"]),
    )


def _money(value: float) -> str:
    return str(Decimal(repr(value)).quantize(Decimal("0.01"), rounding="ROUND_HALF_UP"))


@pytest.mark.parametrize("case", VECTORS, ids=[c["name"] for c in VECTORS])
def test_shared_vectors(case):
    result = project(_inputs(case["input"]))
    expected = case["expected"]

    assert result.months == expected["months"]
    assert _money(result.level.first_year_sip) == expected["level_sip"]
    assert _money(result.step_up.first_year_sip) == expected["step_up_first_sip"]
    assert _money(result.today_value) == expected["today_value"]
    assert result.on_track is expected["on_track"]


@pytest.mark.parametrize("case", VECTORS, ids=[c["name"] for c in VECTORS])
def test_both_plans_reach_the_target(case):
    inputs = _inputs(case["input"])
    result = project(inputs)

    assert result.level.final_balance >= inputs.target - 0.01
    assert result.step_up.final_balance >= inputs.target - 0.01


@pytest.mark.parametrize(
    ("gap", "months", "annual_return"),
    [(9_922_080.48, 144, 0.12), (1_000_000, 60, 0.08), (250_000, 13, 0.30), (500_000, 240, 0.01)],
)
def test_loop_matches_closed_form_when_step_up_is_zero(gap, months, annual_return):
    i = effective_monthly_rate(annual_return)
    closed_form = gap / (((1 + i) ** months - 1) / i * (1 + i))

    assert required_first_sip(gap, months, i, 0.0) == pytest.approx(closed_form, rel=1e-12)


def test_zero_return_splits_gap_evenly():
    assert required_first_sip(600_000, 60, 0.0, 0.0) == pytest.approx(10_000)
    assert required_first_sip(600_000, 60, 0.0, 0.10) < 10_000


def test_goal_under_one_year_has_a_single_partial_row():
    result = project(
        ProjectionInput(
            target=100_000,
            corpus=0,
            annual_return=0.08,
            annual_step_up=0.10,
            inflation=0.06,
            as_of=date(2026, 11, 18),
            target_date=date(2027, 6, 18),
        )
    )

    assert [row.months for row in result.level.rows] == [7]
    assert result.step_up.first_year_sip == result.level.first_year_sip


def test_step_up_starts_lower_and_ends_higher_than_level():
    result = project(_inputs(VECTORS[0]["input"]))

    assert result.step_up.first_year_sip < result.level.first_year_sip
    assert result.step_up.final_year_sip > result.level.final_year_sip
    assert result.step_up.rows[1].monthly_sip == 22_571  # ceil(20,519 × 1.10)


def test_corpus_above_target_needs_no_sip():
    result = project(_inputs(next(c for c in VECTORS if c["name"] == "already_on_track")["input"]))

    assert result.on_track
    assert result.gap == 0
    assert result.level.first_year_sip == 0
    assert all(row.monthly_sip == 0 for row in result.step_up.rows)


@pytest.mark.parametrize(
    ("start", "end", "expected"),
    [
        (date(2026, 11, 18), date(2038, 11, 18), 144),
        (date(2026, 11, 18), date(2027, 11, 17), 11),
        (date(2026, 11, 18), date(2026, 11, 30), 1),
        (date(2026, 1, 31), date(2026, 2, 28), 1),
    ],
)
def test_months_between(start, end, expected):
    assert months_between(start, end) == expected
