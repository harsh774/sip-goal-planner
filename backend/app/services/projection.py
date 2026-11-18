"""SIP projection engine. Pure functions; mirrors the client's Dart engine.

Conventions (see docs/LLD.md §1):
- Effective monthly rate: i = (1 + R)^(1/12) - 1.
- SIP is paid at the start of each month (annuity due).
- Step-up applies once a year, at the start of each goal year.
- Required SIP is rounded up so the plan still reaches the target: to a whole unit,
  or to 0.01 when the target or corpus was entered with decimals.
- Every reported amount is rounded half-up to 2 decimal places.
"""

import math
from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class ProjectionInput:
    target: float
    corpus: float
    annual_return: float
    annual_step_up: float
    inflation: float
    as_of: date
    target_date: date


@dataclass(frozen=True)
class ScheduleRow:
    year: int
    calendar_year: int
    months: int
    monthly_sip: float
    invested_to_date: float
    growth_to_date: float
    closing_balance: float
    goal_pct: float


@dataclass(frozen=True)
class Plan:
    annual_step_up: float
    first_year_sip: float
    final_year_sip: float
    total_invested: float
    growth: float
    final_balance: float
    rows: list[ScheduleRow]


@dataclass(frozen=True)
class Projection:
    as_of: date
    months: int
    monthly_rate: float
    corpus_future_value: float
    gap: float
    today_value: float
    on_track: bool
    level: Plan
    step_up: Plan


def months_between(start: date, end: date) -> int:
    """Whole calendar months from start to end; a trailing partial month is dropped. Minimum 1."""
    months = (end.year - start.year) * 12 + (end.month - start.month)
    if end.day < start.day:
        months -= 1
    return max(months, 1)


def effective_monthly_rate(annual_rate: float) -> float:
    return (1 + annual_rate) ** (1 / 12) - 1


def required_first_sip(gap: float, months: int, monthly_rate: float, step_up: float) -> float:
    """Smallest first-year SIP whose future value equals `gap`.

    FV is linear in the first SIP P0, so P0 = gap / F where
    F = sum over months m of (1 + s)^floor(m / 12) * (1 + i)^(months - m).
    The same sum covers zero return, zero step-up and partial final years.
    """
    if gap <= 0:
        return 0.0
    factor = sum(
        (1 + step_up) ** (m // 12) * (1 + monthly_rate) ** (months - m) for m in range(months)
    )
    return gap / factor


def round_money(value: float) -> float:
    """Half-up to 2 places. Rounding to 6 places first strips float noise (1.005 * 100)."""
    cents = math.floor(round(abs(value) * 100, 6) + 0.5)
    return math.copysign(cents, value) / 100


def _has_cents(value: float) -> bool:
    return round(value * 100) % 100 != 0


def sip_unit(inputs: ProjectionInput) -> float:
    return 0.01 if _has_cents(inputs.target) or _has_cents(inputs.corpus) else 1.0


def _round_up(value: float, unit: float) -> float:
    # Round to 6 places first so float noise (21000.000000000004) doesn't add a unit.
    return round_money(math.ceil(round(value / unit, 6)) * unit)


def _add_months(start: date, months: int) -> tuple[int, int]:
    index = start.year * 12 + (start.month - 1) + months
    return index // 12, index % 12 + 1


def build_plan(
    inputs: ProjectionInput, months: int, monthly_rate: float, step_up: float, gap: float
) -> Plan:
    unit = sip_unit(inputs)
    first_sip = _round_up(required_first_sip(gap, months, monthly_rate, step_up), unit)

    balance = inputs.corpus
    invested = inputs.corpus
    rows: list[ScheduleRow] = []
    sip = first_sip
    for year_index in range(math.ceil(months / 12)):
        sip = _round_up(first_sip * (1 + step_up) ** year_index, unit) if first_sip else 0.0
        months_in_year = min(12, months - year_index * 12)
        for _ in range(months_in_year):
            balance = (balance + sip) * (1 + monthly_rate)
            invested += sip
        closing, invested_so_far = round_money(balance), round_money(invested)
        calendar_year, _month = _add_months(inputs.as_of, year_index * 12 + months_in_year)
        rows.append(
            ScheduleRow(
                year=year_index + 1,
                calendar_year=calendar_year,
                months=months_in_year,
                monthly_sip=sip,
                invested_to_date=invested_so_far,
                growth_to_date=round_money(closing - invested_so_far),
                closing_balance=closing,
                goal_pct=round_money(balance / inputs.target * 100),
            )
        )

    return Plan(
        annual_step_up=step_up,
        first_year_sip=first_sip,
        final_year_sip=sip,
        total_invested=round_money(invested),
        growth=round_money(round_money(balance) - round_money(invested)),
        final_balance=round_money(balance),
        rows=rows,
    )


def project(inputs: ProjectionInput) -> Projection:
    months = months_between(inputs.as_of, inputs.target_date)
    monthly_rate = effective_monthly_rate(inputs.annual_return)
    corpus_fv = inputs.corpus * (1 + monthly_rate) ** months
    gap = inputs.target - corpus_fv

    return Projection(
        as_of=inputs.as_of,
        months=months,
        monthly_rate=monthly_rate,
        corpus_future_value=round_money(corpus_fv),
        gap=round_money(max(gap, 0.0)),
        today_value=round_money(inputs.target / (1 + inputs.inflation) ** (months / 12)),
        on_track=gap <= 0,
        level=build_plan(inputs, months, monthly_rate, 0.0, gap),
        step_up=build_plan(inputs, months, monthly_rate, inputs.annual_step_up, gap),
    )
