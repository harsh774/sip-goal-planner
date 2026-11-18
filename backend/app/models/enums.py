"""Fixed value sets, stored as native PostgreSQL enum types.

Adding a value later needs its own migration with `ALTER TYPE ... ADD VALUE`;
Alembic autogenerate does not detect enum value changes.
"""

from enum import StrEnum

from sqlalchemy import Enum as SAEnum


class Currency(StrEnum):
    INR = "INR"
    USD = "USD"
    EUR = "EUR"
    GBP = "GBP"
    AED = "AED"
    SGD = "SGD"
    AUD = "AUD"
    CAD = "CAD"
    JPY = "JPY"
    CNY = "CNY"
    BRL = "BRL"


# Minor-unit digits per currency (ISO 4217). Governs validation and display only;
# storage always uses a scale of 100.
CURRENCY_DECIMALS: dict[Currency, int] = {c: 2 for c in Currency} | {Currency.JPY: 0}


class TransportKeyStatus(StrEnum):
    ACTIVE = "active"  # handed to clients for new requests
    RETIRED = "retired"  # replaced by a newer version; accepted during the grace period
    REVOKED = "revoked"  # never accepted again


class GoalType(StrEnum):
    HOME = "home"
    EDUCATION = "education"
    RETIREMENT = "retirement"
    CAR = "car"
    WEDDING = "wedding"
    TRAVEL = "travel"
    EMERGENCY_FUND = "emergency_fund"
    OTHER = "other"


class GoalAction(StrEnum):
    CREATED = "created"
    UPDATED = "updated"
    DELETED = "deleted"


def _pg_enum(enum_cls: type[StrEnum], name: str) -> SAEnum:
    return SAEnum(
        enum_cls,
        name=name,
        values_callable=lambda e: [m.value for m in e],
        validate_strings=True,
    )


# One SQLAlchemy type object per PostgreSQL type, shared by every column that uses it.
currency_enum = _pg_enum(Currency, "currency_code")
goal_type_enum = _pg_enum(GoalType, "goal_type")
transport_key_status_enum = _pg_enum(TransportKeyStatus, "transport_key_status")
goal_action_enum = _pg_enum(GoalAction, "goal_action")
