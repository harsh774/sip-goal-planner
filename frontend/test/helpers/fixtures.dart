import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_action.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_type.dart';

final asOf = DateTime(2026, 11, 18);

/// The brief's example: ₹1 crore in 12 years, ₹20,000 invested, 12% a year.
Goal goalFixture({
  String id = 'g1',
  Currency currency = Currency.inr,
  int targetAmount = 1000000000,
  int currentCorpus = 2000000,
  GoalAction? action,
}) => Goal(
  id: id,
  name: 'Daughter’s education',
  type: GoalType.education,
  currency: currency,
  targetAmount: targetAmount,
  targetDate: DateTime(2038, 11, 18),
  currentCorpus: currentCorpus,
  expectedReturnBp: 1200,
  annualStepUpBp: 1000,
  inflationBp: 600,
  action: action,
);
