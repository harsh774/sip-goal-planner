import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/features/projection/domain/usecases/calculate_projection.dart';
import 'package:sip_goal_planner/features/projection/presentation/widgets/plan_preview_panel.dart';

import '../../../helpers/fixtures.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('asks for valid input while the form is invalid', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PlanPreviewPanel(
          projection: null,
          currency: Currency.inr,
          target: null,
          targetDate: null,
          stepUpPct: '10',
        ),
      ),
    );

    expect(find.text('Fill in the highlighted fields to see your plan.'), findsOneWidget);
    expect(
      find.textContaining('Mutual fund investments are subject to market risks.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the SIP from the local engine', (tester) async {
    final goal = goalFixture();
    final projection = CalculateProjection(clock: () => asOf)(goal.toDraft());

    await tester.pumpWidget(
      _wrap(
        PlanPreviewPanel(
          projection: projection,
          currency: Currency.inr,
          target: 10000000,
          targetDate: goal.targetDate,
          stepUpPct: '10',
        ),
      ),
    );

    expect(find.text('₹32,205'), findsOneWidget);
    expect(find.text('₹20,519'), findsOneWidget);
  });
}
