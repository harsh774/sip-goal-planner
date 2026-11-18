import 'package:intl/intl.dart';

import '../domain/currency.dart';
import '../domain/rounding.dart';

/// Formats amounts the way the design shows them: Indian lakh/crore for INR,
/// compact notation for other currencies.
abstract final class MoneyFormatter {
  static const _lakh = 1e5;
  static const _crore = 1e7;

  /// ₹32,205 · ₹17,640.80 · $1,250 — cents only when the amount has them.
  static String full(num amount, Currency currency) {
    final rounded = roundMoney(amount.toDouble());
    final digits = hasCents(rounded) ? currency.decimals : 0;
    return NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: digits,
    ).format(digits == 0 ? rounded.round() : rounded);
  }

  /// ₹1.00 Cr · ₹25.00 L · $1.2M
  static String short(num amount, Currency currency) {
    final abs = amount.abs();
    if (currency == Currency.inr) {
      if (abs >= _crore) return '${currency.symbol}${(amount / _crore).toStringAsFixed(2)} Cr';
      if (abs >= _lakh) return '${currency.symbol}${(amount / _lakh).toStringAsFixed(2)} L';
      return full(amount, currency);
    }
    if (abs < 1e4) return full(amount, currency);
    return NumberFormat.compactCurrency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 2,
    ).format(amount);
  }

  /// ₹1 crore · ₹25 lakh · $1.25 million
  static String words(num amount, Currency currency) {
    if (currency == Currency.inr) {
      if (amount >= _crore) return '${currency.symbol}${_trim(amount / _crore)} crore';
      if (amount >= _lakh) return '${currency.symbol}${_trim(amount / _lakh)} lakh';
      return full(amount, currency);
    }
    if (amount < 1e6) return full(amount, currency);
    if (amount < 1e9) return '${currency.symbol}${_trim(amount / 1e6)} million';
    return '${currency.symbol}${_trim(amount / 1e9)} billion';
  }

  /// Axis labels: ₹50 L · ₹1.2 Cr · $500K
  static String axis(num amount, Currency currency) {
    if (amount == 0) return '0';
    if (currency == Currency.inr) {
      if (amount >= _crore) return '${currency.symbol}${_trim(amount / _crore)} Cr';
      if (amount >= _lakh) return '${currency.symbol}${_trim(amount / _lakh, 1)} L';
      return '${currency.symbol}${(amount / 1e3).round()}K';
    }
    return NumberFormat.compactCurrency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    ).format(amount);
  }

  static String _trim(num value, [int digits = 2]) =>
      value.toStringAsFixed(digits).replaceFirst(RegExp(r'\.?0+$'), '');
}

abstract final class DateFormats {
  static final monthYear = DateFormat('MMM yyyy');
  static final dayMonthYear = DateFormat('d MMM yyyy');

  /// "4 years 4 months", "7 months"
  static String duration(int months) {
    final years = months ~/ 12;
    final rest = months % 12;
    final parts = [
      if (years > 0) '$years ${years == 1 ? 'year' : 'years'}',
      if (rest > 0) '$rest ${rest == 1 ? 'month' : 'months'}',
    ];
    return parts.isEmpty ? '0 months' : parts.join(' ');
  }
}
