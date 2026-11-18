import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_projection.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/plan_goals.dart';

import '../../../helpers/fixtures.dart';

void main() {
  final plan = PlanGoals(CalculateProjection(clock: () => asOf));

  test('plans each goal in its own currency with the local engine', () {
    final plans = plan([goalFixture(), goalFixture(id: 'usd', currency: Currency.usd)]);

    expect(plans.map((p) => p.levelSip), [32205, 32205]);
    expect(plans.map((p) => p.stepUpFirstSip), [20519, 20519]);
    expect(plans.first.progressPct, closeTo(0.2, 1e-9));
  });
}
