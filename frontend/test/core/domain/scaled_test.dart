import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/scaled.dart';

void main() {
  test('parses decimal strings exactly, without going through double', () {
    expect(Scaled.parse('0.10'), 10);
    expect(Scaled.parse('0.1'), 10);
    expect(Scaled.parse('2500000.50'), 250000050);
    expect(Scaled.parse('12.5'), 1250);
    expect(Scaled.parse('-0.05'), -5);
  });

  test('round-trips every paisa', () {
    for (final raw in ['0.01', '0.29', '1234567.89', '999999999999.99']) {
      expect(Scaled.format(Scaled.parse(raw)), raw);
    }
  });

  test('rejects more than two decimals and non-numbers', () {
    expect(Scaled.tryParse('1.234'), isNull);
    expect(Scaled.tryParse('abc'), isNull);
    expect(Scaled.tryParse(''), isNull);
    expect(() => Scaled.parse('1e5'), throwsFormatException);
  });

  test('compact form drops trailing zeros', () {
    expect(Scaled.formatCompact(1250), '12.5');
    expect(Scaled.formatCompact(700), '7');
    expect(Scaled.formatCompact(1234), '12.34');
  });
}
