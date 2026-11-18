import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/features/projection/presentation/widgets/plan_tables.dart';

void main() {
  test('long plans collapse to the first three, every fifth and the last year', () {
    expect(YearlyTable.keyRows(25), [0, 1, 2, 4, 9, 14, 19, 24]);
    expect(YearlyTable.keyRows(12), [0, 1, 2, 4, 9, 11]);
  });
}
