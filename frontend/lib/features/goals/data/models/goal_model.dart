import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_action.dart';
import '../../domain/entities/goal_type.dart';

abstract final class GoalModel {
  static Goal fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    name: json['name'] as String,
    type: GoalType.fromCode(json['goal_type'] as String),
    currency: Currency.fromCode(json['currency'] as String),
    targetAmount: Scaled.parse(json['target_amount'] as String),
    targetDate: DateTime.parse(json['target_date'] as String),
    currentCorpus: Scaled.parse(json['current_corpus'] as String),
    expectedReturnBp: Scaled.parse(json['expected_return_pct'] as String),
    annualStepUpBp: Scaled.parse(json['annual_step_up_pct'] as String),
    inflationBp: Scaled.parse(json['inflation_pct'] as String),
    action: GoalAction.tryFromCode(json['action'] as String?),
  );

  /// Body for POST (with currency) or PATCH (currency is fixed after creation).
  static Map<String, dynamic> toJson(GoalDraft draft, {required bool includeCurrency}) => {
    'name': draft.name,
    'goal_type': draft.type.code,
    if (includeCurrency) 'currency': draft.currency.code,
    'target_amount': Scaled.format(draft.targetAmount),
    'target_date': _isoDate(draft.targetDate),
    'current_corpus': Scaled.format(draft.currentCorpus),
    'expected_return_pct': Scaled.format(draft.expectedReturnBp),
    'annual_step_up_pct': Scaled.format(draft.annualStepUpBp),
    'inflation_pct': Scaled.format(draft.inflationBp),
  };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
