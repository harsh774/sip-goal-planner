import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/core/format/amount_words.dart';

void main() {
  test('INR uses crore, lakh and thousand', () {
    expect(AmountWords.of(55500500, Currency.inr), '5 lakh 55 thousand 5 rupees');
    expect(AmountWords.of(1000000000, Currency.inr), '1 crore rupees');
    expect(AmountWords.of(1200000000000, Currency.inr), '1200 crore rupees');
    expect(AmountWords.of(100, Currency.inr), '1 rupee');
    expect(AmountWords.of(2000050, Currency.inr), '20 thousand rupees and 50 paise');
    expect(AmountWords.of(0, Currency.inr), '0 rupees');
  });

  test('other currencies use million and billion', () {
    expect(AmountWords.of(125000050, Currency.usd), '1 million 250 thousand dollars and 50 cents');
    expect(AmountWords.of(90000000, Currency.jpy), '900 thousand yen');
    expect(AmountWords.of(101, Currency.gbp), '1 pound and 1 penny');
  });
}
