import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/core/format/money_formatter.dart';

void main() {
  test('INR uses Indian grouping and lakh/crore', () {
    expect(MoneyFormatter.full(10000000, Currency.inr), '₹1,00,00,000');
    expect(MoneyFormatter.short(10000000, Currency.inr), '₹1.00 Cr');
    expect(MoneyFormatter.short(2500000, Currency.inr), '₹25.00 L');
    expect(MoneyFormatter.words(4969693.64, Currency.inr), '₹49.7 lakh');
  });

  test('other currencies use western grouping and compact notation', () {
    expect(MoneyFormatter.full(32205, Currency.usd), r'$32,205');
    expect(MoneyFormatter.short(1200000, Currency.usd), r'$1.2M');
  });

  test('JPY has no decimals', () {
    expect(MoneyFormatter.full(1234.6, Currency.jpy), '¥1,235');
  });

  test('duration reads naturally', () {
    expect(DateFormats.duration(52), '4 years 4 months');
    expect(DateFormats.duration(12), '1 year');
    expect(DateFormats.duration(7), '7 months');
  });
}
