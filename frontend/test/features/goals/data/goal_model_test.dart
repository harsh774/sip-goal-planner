import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/features/goals/data/models/goal_model.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_action.dart';

Map<String, dynamic> _json({Object? action}) => {
  'id': 'g1',
  'name': 'Car',
  'goal_type': 'car',
  'currency': 'INR',
  'target_amount': '500000.00',
  'target_date': '2027-06-18',
  'current_corpus': '0.00',
  'expected_return_pct': '10.00',
  'annual_step_up_pct': '0.00',
  'inflation_pct': '2.00',
  'action': action,
};

void main() {
  test('reads action and flags completed goals', () {
    final goal = GoalModel.fromJson(_json(action: 'completed'));
    expect(goal.action, GoalAction.completed);
    expect(goal.isCompleted, isTrue);

    expect(GoalModel.fromJson(_json(action: 'updated')).isCompleted, isFalse);
  });

  test('a missing or unknown action is tolerated', () {
    expect(GoalModel.fromJson(_json()).action, isNull);
    expect(GoalModel.fromJson(_json(action: 'archived')).action, isNull);
  });
}
