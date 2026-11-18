import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/features/projection/domain/fx/fx_rates.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_goal_totals.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_projection.dart';

import '../../../helpers/fixtures.dart';

void main() {
  final totals = CalculateGoalTotals(CalculateProjection(clock: () => asOf));

  test('goals in one currency are summed exactly and not flagged as approximate', () {
    final overview = totals([goalFixture(id: 'a'), goalFixture(id: 'b')], Currency.inr);

    expect(overview.totals.monthlySip, 32205 * 2);
    expect(overview.totals.converted, isFalse);
    expect(overview.summaries.map((s) => s.levelSip), [32205, 32205]);
  });

  test('mixed currencies are converted into the chosen one and flagged', () {
    final inr = goalFixture(id: 'inr');
    final usd = goalFixture(id: 'usd', currency: Currency.usd);

    final overview = totals([inr, usd], Currency.usd);
    final expected = 32205 + FxRates.convert(32205, Currency.inr, Currency.usd);

    expect(overview.totals.monthlySip, closeTo(expected, 1e-9));
    expect(overview.totals.converted, isTrue);
    // A goal's own numbers are never converted.
    expect(overview.summaries.first.levelSip, 32205);
  });
}
