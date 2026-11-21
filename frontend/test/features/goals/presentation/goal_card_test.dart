import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_action.dart';
import 'package:sip_goal_planner/features/goals/presentation/widgets/goal_card.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_projection.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/plan_goals.dart';

import '../../../helpers/fixtures.dart';

Future<void> _pump(WidgetTester tester, GoalAction? action) {
  final plan = PlanGoals(CalculateProjection(clock: () => asOf))([
    goalFixture(action: action),
  ]).single;
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GoalCard(plan: plan, onOpen: () {}),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a completed goal shows the green badge instead of the SIP', (tester) async {
    await _pump(tester, GoalAction.completed);

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Goal completed'), findsOneWidget);
    expect(find.text('Invest every month'), findsNothing);
  });

  testWidgets('an open goal shows the monthly SIP and no badge', (tester) async {
    await _pump(tester, GoalAction.created);

    expect(find.text('Completed'), findsNothing);
    expect(find.text('Invest every month'), findsOneWidget);
  });
}
