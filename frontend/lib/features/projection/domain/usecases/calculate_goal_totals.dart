import 'package:equatable/equatable.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../../goals/domain/entities/goal.dart';
import '../entities/projection.dart';
import '../fx/fx_rates.dart';
import 'calculate_projection.dart';

class GoalSummary extends Equatable {
  const GoalSummary({required this.goal, required this.projection});

  final Goal goal;
  final Projection projection;

  double get levelSip => projection.level.firstYearSip;
  double get stepUpFirstSip => projection.stepUp.firstYearSip;
  double get progressPct =>
      goal.targetAmount == 0 ? 0 : goal.currentCorpus / goal.targetAmount * 100;

  @override
  List<Object?> get props => [goal, projection];
}

class GoalTotals extends Equatable {
  const GoalTotals({
    required this.currency,
    required this.monthlySip,
    required this.target,
    required this.converted,
  });

  final Currency currency;
  final double monthlySip;
  final double target;

  /// True when at least one goal was in another currency, so the total is approximate.
  final bool converted;

  DateTime get ratesAsOf => FxRates.asOf;

  @override
  List<Object?> get props => [currency, monthlySip, target, converted];
}

class GoalOverview extends Equatable {
  const GoalOverview({required this.summaries, required this.totals});

  final List<GoalSummary> summaries;
  final GoalTotals totals;

  @override
  List<Object?> get props => [summaries, totals];
}

class CalculateGoalTotals {
  const CalculateGoalTotals(this._calculate);

  final CalculateProjection _calculate;

  GoalOverview call(List<Goal> goals, Currency totalCurrency) {
    final summaries = [
      for (final goal in goals) GoalSummary(goal: goal, projection: _calculate(goal.toDraft())),
    ];
    var sip = 0.0;
    var target = 0.0;
    for (final s in summaries) {
      sip += FxRates.convert(s.levelSip, s.goal.currency, totalCurrency);
      target += FxRates.convert(
        Scaled.toDouble(s.goal.targetAmount),
        s.goal.currency,
        totalCurrency,
      );
    }
    return GoalOverview(
      summaries: summaries,
      totals: GoalTotals(
        currency: totalCurrency,
        monthlySip: sip,
        target: target,
        converted: goals.any((g) => g.currency != totalCurrency),
      ),
    );
  }
}
