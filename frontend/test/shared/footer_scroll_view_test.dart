import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/shared/widgets/app_footer.dart';

void main() {
  testWidgets('the footer sits at the bottom of a short page', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FooterScrollView(child: SizedBox(height: 100))),
      ),
    );

    final copyright = tester.getBottomLeft(find.textContaining('All rights reserved'));
    expect(copyright.dy, greaterThan(850));
  });
}
