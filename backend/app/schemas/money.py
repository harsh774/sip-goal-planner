"""String <-> scaled-integer conversion for money and percentages.

The API sends and receives decimals as strings ("2500000.50", "12.5").
They are parsed with Decimal (never float) and stored as integers scaled by 100:
  money -> hundredths of a unit   ("2500000.50" -> 250000050)
  rates -> basis points           ("12.5"       -> 1250)
On the way out they are rendered back to strings with two decimals.
"""

from decimal import Decimal, InvalidOperation
from typing import Annotated

from pydantic import BeforeValidator, PlainSerializer, WithJsonSchema
from pydantic_core import PydanticCustomError

SCALE = 100
_TWO_PLACES = Decimal("0.01")


def parse_scaled(value: object) -> int:
    """Parse a decimal string (or int) into an integer scaled by 100."""
    if isinstance(value, bool) or not isinstance(value, str | int):
        raise PydanticCustomError(
            "not_a_number", 'Enter a number as a string, for example "2500000.50".'
        )
    try:
        amount = Decimal(str(value).strip())
    except InvalidOperation:
        raise PydanticCustomError("not_a_number", "Enter a number.") from None
    if not amount.is_finite():
        raise PydanticCustomError("not_a_number", "Enter a number.")
    if amount != amount.quantize(_TWO_PLACES):
        raise PydanticCustomError("too_many_decimals", "Use at most 2 decimal places.")
    return int(amount * SCALE)


def format_scaled(value: int) -> str:
    """Render an integer scaled by 100 as a decimal string with two places."""
    sign = "-" if value < 0 else ""
    whole, frac = divmod(abs(int(value)), SCALE)
    return f"{sign}{whole}.{frac:02d}"


def format_float(value: float) -> str:
    """Render a computed float as a decimal string with two places (half-up)."""
    return str(Decimal(repr(value)).quantize(_TWO_PLACES, rounding="ROUND_HALF_UP"))


_DECIMAL_STRING_SCHEMA = WithJsonSchema(
    {"type": "string", "pattern": r"^-?\d+(\.\d{1,2})?$", "examples": ["2500000.00"]}
)

Scaled = Annotated[
    int,
    BeforeValidator(parse_scaled),
    PlainSerializer(format_scaled, return_type=str),
    _DECIMAL_STRING_SCHEMA,
]

ScaledOut = Annotated[int, PlainSerializer(format_scaled, return_type=str), _DECIMAL_STRING_SCHEMA]

DecimalOut = Annotated[
    float, PlainSerializer(format_float, return_type=str), _DECIMAL_STRING_SCHEMA
]
