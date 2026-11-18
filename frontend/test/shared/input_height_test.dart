import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/app/theme/app_theme.dart';

void main() {
  testWidgets('a text field keeps its height when focused', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Column(children: [TextField(decoration: InputDecoration(labelText: 'Name'))]),
        ),
      ),
    );
    final before = tester.getSize(find.byType(TextField)).height;

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(TextField)).height, before);
  });
}
