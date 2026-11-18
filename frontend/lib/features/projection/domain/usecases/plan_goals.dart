import 'package:equatable/equatable.dart';

import '../../../goals/domain/entities/goal.dart';
import '../entities/projection.dart';
import 'calculate_projection.dart';

/// A goal with its plan, as shown on a goal card.
class GoalPlan extends Equatable {
  const GoalPlan({required this.goal, required this.projection});

  final Goal goal;
  final Projection projection;

  double get levelSip => projection.level.firstYearSip;
  double get stepUpFirstSip => projection.stepUp.firstYearSip;
  double get progressPct =>
      goal.targetAmount == 0 ? 0 : goal.currentCorpus / goal.targetAmount * 100;

  @override
  List<Object?> get props => [goal, projection];
}

class PlanGoals {
  const PlanGoals(this._calculate);

  final CalculateProjection _calculate;

  List<GoalPlan> call(List<Goal> goals) => [
    for (final goal in goals) GoalPlan(goal: goal, projection: _calculate(goal.toDraft())),
  ];
}
