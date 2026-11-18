import '../../../../core/domain/scaled.dart';
import '../../../goals/domain/entities/goal.dart';
import '../engine/projection_calculator.dart';
import '../entities/projection.dart';

/// Pure and synchronous: every number the app shows comes from here, not the server.
class CalculateProjection {
  const CalculateProjection({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  Projection call(GoalDraft draft) => ProjectionCalculator.project(inputFor(draft, _clock()));

  static ProjectionInput inputFor(GoalDraft draft, DateTime asOf) => ProjectionInput(
    target: Scaled.toDouble(draft.targetAmount),
    corpus: Scaled.toDouble(draft.currentCorpus),
    annualReturn: draft.expectedReturnBp / 10000,
    annualStepUp: draft.annualStepUpBp / 10000,
    inflation: draft.inflationBp / 10000,
    asOf: DateTime(asOf.year, asOf.month, asOf.day),
    targetDate: draft.targetDate,
  );
}
