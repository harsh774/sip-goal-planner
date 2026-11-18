import '../../../../core/domain/currency.dart';

/// Fixed exchange-rate snapshot used only for the "My goals" total.
/// Source: European Central Bank reference rates via frankfurter.dev, base USD,
/// on [asOf]. AED is derived from its fixed USD peg (3.6725).
abstract final class FxRates {
  static final asOf = DateTime(2026, 11, 18);

  /// Units of each currency per 1 USD.
  static const perUsd = <Currency, double>{
    Currency.usd: 1,
    Currency.inr: 93.44,
    Currency.eur: 0.91174,
    Currency.gbp: 0.75939,
    Currency.aed: 3.6725,
    Currency.sgd: 1.2896,
    Currency.aud: 1.4856,
    Currency.cad: 1.4305,
    Currency.jpy: 159.42,
    Currency.cny: 6.6672,
    Currency.brl: 5.8186,
  };

  static double convert(double amount, Currency from, Currency to) =>
      from == to ? amount : amount / perUsd[from]! * perUsd[to]!;
}
