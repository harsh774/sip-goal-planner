import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/features/projection/domain/engine/projection_calculator.dart';
import 'package:sip_goal_planner/features/projection/domain/entities/projection.dart';

/// The same file the backend's pytest suite runs, so both engines agree.
final _vectors =
    (jsonDecode(File('../shared/projection_vectors.json').readAsStringSync())
            as Map<String, dynamic>)['cases']
        as List<dynamic>;

ProjectionInput _input(Map<String, dynamic> raw) => ProjectionInput(
  target: double.parse(raw['target_amount'] as String),
  corpus: double.parse(raw['current_corpus'] as String),
  annualReturn: double.parse(raw['expected_return_pct'] as String) / 100,
  annualStepUp: double.parse(raw['annual_step_up_pct'] as String) / 100,
  inflation: double.parse(raw['inflation_pct'] as String) / 100,
  asOf: DateTime.parse(raw['as_of'] as String),
  targetDate: DateTime.parse(raw['target_date'] as String),
);

void main() {
  group('shared vectors', () {
    for (final raw in _vectors.cast<Map<String, dynamic>>()) {
      final input = _input(raw['input'] as Map<String, dynamic>);
      final expected = raw['expected'] as Map<String, dynamic>;

      test(raw['name'] as String, () {
        final result = ProjectionCalculator.project(input);

        expect(result.months, expected['months']);
        expect(result.level.firstYearSip.toStringAsFixed(2), expected['level_sip']);
        expect(result.stepUp.firstYearSip.toStringAsFixed(2), expected['step_up_first_sip']);
        expect(result.todayValue.toStringAsFixed(2), expected['today_value']);
        expect(result.onTrack, expected['on_track']);
        expect(result.level.finalBalance, greaterThanOrEqualTo(input.target - 0.01));
        expect(result.stepUp.finalBalance, greaterThanOrEqualTo(input.target - 0.01));
      });
    }
  });

  test('loop matches the closed form when step-up is zero', () {
    final i = ProjectionCalculator.effectiveMonthlyRate(0.12);
    const gap = 9922080.48;
    const n = 144;
    final closedForm = gap / (((_pow(1 + i, n)) - 1) / i * (1 + i));

    expect(ProjectionCalculator.requiredFirstSip(gap, n, i, 0), closeTo(closedForm, 1e-6));
  });

  test('step-up raises the SIP once a year, rounded up to whole units', () {
    final result = ProjectionCalculator.project(
      _input((_vectors.first as Map<String, dynamic>)['input'] as Map<String, dynamic>),
    );

    expect(result.stepUp.rows.map((r) => r.monthlySip).take(2), [20519, 22571]);
    expect(result.stepUp.finalYearSip, greaterThan(result.level.finalYearSip));
  });

  test('months between drops a trailing partial month', () {
    expect(ProjectionCalculator.monthsBetween(DateTime(2026, 11, 18), DateTime(2027, 11, 17)), 11);
    expect(ProjectionCalculator.monthsBetween(DateTime(2026, 11, 18), DateTime(2026, 11, 30)), 1);
  });
}

double _pow(double base, int exp) {
  var result = 1.0;
  for (var k = 0; k < exp; k++) {
    result *= base;
  }
  return result;
}
