import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/rounding.dart';

void main() {
  test('roundMoney is half-up to two places, like the backend', () {
    expect(roundMoney(1.005), 1.01);
    expect(roundMoney(2.675), 2.68);
    expect(roundMoney(-1.005), -1.01);
    expect(roundMoney(0.004999), 0);
    expect(roundMoney(1234.5650000001), 1234.57);
  });

  test('hasCents ignores float noise', () {
    expect(hasCents(2500000.50), isTrue);
    expect(hasCents(20000), isFalse);
    expect(hasCents(21000.000000000004), isFalse);
  });
}
