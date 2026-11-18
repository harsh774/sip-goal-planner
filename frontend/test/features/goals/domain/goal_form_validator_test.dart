import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_type.dart';
import 'package:sip_goal_planner/features/goals/domain/validation/goal_form_validator.dart';

import '../../../helpers/fixtures.dart';

GoalFormInput _input({
  String name = 'Home down payment',
  GoalType? type = GoalType.home,
  Currency currency = Currency.inr,
  String target = '2500000',
  DateTime? date,
  String corpus = '350000.50',
  String ret = '12.5',
  String step = '5',
  String inflation = '6',
}) => GoalFormInput(
  name: name,
  type: type,
  currency: currency,
  targetAmount: target,
  targetDate: date ?? DateTime(2031, 3, 1),
  currentCorpus: corpus,
  expectedReturn: ret,
  annualStepUp: step,
  inflation: inflation,
);

void main() {
  test('valid input becomes a draft in scaled integers', () {
    final result = GoalFormValidator.validate(_input(), today: asOf);

    expect(result.isValid, isTrue);
    expect(result.draft!.targetAmount, 250000000);
    expect(result.draft!.currentCorpus, 35000050);
    expect(result.draft!.expectedReturnBp, 1250);
  });

  test('mirrors the API rules, keyed by API field names', () {
    final result = GoalFormValidator.validate(
      _input(
        name: ' ',
        type: null,
        target: '0',
        date: DateTime(2020),
        corpus: '1.234',
        ret: '31',
        step: '26',
        inflation: '13',
      ),
      today: asOf,
    );

    expect(result.errors.keys, {
      'name',
      'goal_type',
      'target_amount',
      'target_date',
      'current_corpus',
      'expected_return_pct',
      'annual_step_up_pct',
      'inflation_pct',
    });
  });

  test('JPY amounts cannot have decimals', () {
    final result = GoalFormValidator.validate(
      _input(currency: Currency.jpy, target: '100.50'),
      today: asOf,
    );

    expect(result.errors['target_amount'], contains('JPY'));
  });

  test('today is not a valid target date', () {
    final result = GoalFormValidator.validate(_input(date: asOf), today: asOf);
    expect(result.errors['target_date'], 'Target date must be in the future.');
  });
}
