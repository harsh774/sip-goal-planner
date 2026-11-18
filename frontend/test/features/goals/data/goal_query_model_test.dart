import 'package:flutter_test/flutter_test.dart';
import 'package:sip_goal_planner/core/domain/currency.dart';
import 'package:sip_goal_planner/features/goals/data/models/goal_query_model.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_query.dart';
import 'package:sip_goal_planner/features/goals/domain/entities/goal_type.dart';

void main() {
  test('an empty query sends only paging and sort', () {
    expect(GoalQueryModel.toQuery(const GoalQuery()), {
      'sort': 'newest',
      'page': 1,
      'page_size': 10,
    });
  });

  test('filters map to the API parameter names, with amounts as decimal strings', () {
    const query = GoalQuery(
      filters: GoalFilters(
        currency: Currency.inr,
        type: GoalType.emergencyFund,
        minTargetAmount: 100000000,
        maxTargetAmount: 250000050,
        yearFrom: 2030,
        yearTo: 2040,
      ),
      sort: GoalSort.targetDate,
      page: 2,
    );

    expect(GoalQueryModel.toQuery(query), {
      'currency': 'INR',
      'goal_type': 'emergency_fund',
      'min_target_amount': '1000000.00',
      'max_target_amount': '2500000.50',
      'target_year_from': 2030,
      'target_year_to': 2040,
      'sort': 'target_date',
      'page': 2,
      'page_size': 10,
    });
  });

  test('parses a page and a summary', () {
    final page = GoalQueryModel.pageFromJson({
      'items': <Object>[],
      'page': 2,
      'page_size': 10,
      'total': 25,
      'total_pages': 3,
    });
    final summary = GoalQueryModel.summaryFromJson({
      'count': 5,
      'currency': 'USD',
      'total_monthly_sip': '844.31',
      'total_target': '1112000.00',
      'converted': true,
      'rates_as_of': '2026-11-18',
    });

    expect((page.hasPrevious, page.hasNext), (true, true));
    expect(summary.totalMonthlySip, 844.31);
    expect(summary.converted, isTrue);
  });
}
