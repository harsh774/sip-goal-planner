import 'package:equatable/equatable.dart';

import '../../../../core/domain/currency.dart';
import 'goal_type.dart';

/// A saved goal. Money is in hundredths of [currency]; rates are in basis points.
class Goal extends Equatable {
  const Goal({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.targetAmount,
    required this.targetDate,
    required this.currentCorpus,
    required this.expectedReturnBp,
    required this.annualStepUpBp,
    required this.inflationBp,
  });

  final String id;
  final String name;
  final GoalType type;
  final Currency currency;
  final int targetAmount;
  final DateTime targetDate;
  final int currentCorpus;
  final int expectedReturnBp;
  final int annualStepUpBp;
  final int inflationBp;

  GoalDraft toDraft() => GoalDraft(
    name: name,
    type: type,
    currency: currency,
    targetAmount: targetAmount,
    targetDate: targetDate,
    currentCorpus: currentCorpus,
    expectedReturnBp: expectedReturnBp,
    annualStepUpBp: annualStepUpBp,
    inflationBp: inflationBp,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    currency,
    targetAmount,
    targetDate,
    currentCorpus,
    expectedReturnBp,
    annualStepUpBp,
    inflationBp,
  ];
}

/// Validated values for creating or updating a goal (no id yet).
class GoalDraft extends Equatable {
  const GoalDraft({
    required this.name,
    required this.type,
    required this.currency,
    required this.targetAmount,
    required this.targetDate,
    required this.currentCorpus,
    required this.expectedReturnBp,
    required this.annualStepUpBp,
    required this.inflationBp,
  });

  final String name;
  final GoalType type;
  final Currency currency;
  final int targetAmount;
  final DateTime targetDate;
  final int currentCorpus;
  final int expectedReturnBp;
  final int annualStepUpBp;
  final int inflationBp;

  @override
  List<Object?> get props => [
    name,
    type,
    currency,
    targetAmount,
    targetDate,
    currentCorpus,
    expectedReturnBp,
    annualStepUpBp,
    inflationBp,
  ];
}
