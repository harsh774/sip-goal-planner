import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_query.dart';
import 'package:sip_goal_planner/features/goals/presentation/widgets/goal_filters_bar.dart';

void main() {
  test('timeline presets map to year ranges and back', () {
    const now = 2026;
    for (final t in Timeline.values) {
      final (from, to) = t.years(now);
      expect(Timeline.of(GoalFilters(yearFrom: from, yearTo: to), now), t);
    }
    expect(Timeline.fiveToTen.years(now), (2031, 2036));
    expect(Timeline.of(const GoalFilters(yearFrom: 2040, yearTo: 2041), now), Timeline.any);
  });
}
