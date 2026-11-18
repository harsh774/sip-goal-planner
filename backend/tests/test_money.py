import pytest
from pydantic_core import PydanticCustomError

from app.schemas.money import format_float, format_scaled, parse_scaled


@pytest.mark.parametrize(
    ("raw", "scaled"),
    [("0.10", 10), ("0.1", 10), ("2500000.50", 250000050), ("12.5", 1250), ("7", 700), (7, 700)],
)
def test_parse_scaled_is_exact(raw, scaled):
    assert parse_scaled(raw) == scaled


@pytest.mark.parametrize(
    ("scaled", "text"), [(10, "0.10"), (250000050, "2500000.50"), (-5, "-0.05")]
)
def test_format_scaled(scaled, text):
    assert format_scaled(scaled) == text


def test_round_trip_keeps_every_paisa():
    for raw in ("0.01", "0.29", "1234567.89", "999999999999.99"):
        assert format_scaled(parse_scaled(raw)) == raw


@pytest.mark.parametrize(
    ("raw", "code"),
    [
        ("1.234", "too_many_decimals"),
        ("abc", "not_a_number"),
        ("NaN", "not_a_number"),
        (12.5, "not_a_number"),
        (True, "not_a_number"),
    ],
)
def test_parse_scaled_rejects(raw, code):
    with pytest.raises(PydanticCustomError) as exc:
        parse_scaled(raw)
    assert exc.value.type == code


def test_format_float_rounds_half_up():
    assert format_float(4969693.635770006) == "4969693.64"
    assert format_float(0.125) == "0.13"
