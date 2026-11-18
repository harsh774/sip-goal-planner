"""Fixed exchange-rate snapshot, used only to add up goals held in different currencies.

Source: European Central Bank reference rates via frankfurter.dev, base USD, on
RATES_AS_OF. AED comes from its fixed USD peg (3.6725). A goal's own numbers are
never converted.
"""

from datetime import date

from app.models.enums import Currency

RATES_AS_OF = date(2026, 11, 18)

RATES_PER_USD: dict[Currency, float] = {
    Currency.USD: 1.0,
    Currency.INR: 93.44,
    Currency.EUR: 0.91174,
    Currency.GBP: 0.75939,
    Currency.AED: 3.6725,
    Currency.SGD: 1.2896,
    Currency.AUD: 1.4856,
    Currency.CAD: 1.4305,
    Currency.JPY: 159.42,
    Currency.CNY: 6.6672,
    Currency.BRL: 5.8186,
}


def convert(amount: float, source: Currency, target: Currency) -> float:
    if source == target:
        return amount
    return amount / RATES_PER_USD[source] * RATES_PER_USD[target]
