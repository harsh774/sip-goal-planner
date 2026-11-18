import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_query.dart';
import 'goal_model.dart';

abstract final class GoalQueryModel {
  static Map<String, dynamic> filtersToQuery(GoalFilters f) => {
    'currency': ?f.currency?.code,
    'goal_type': ?f.type?.code,
    if (f.minTargetAmount case final min?) 'min_target_amount': Scaled.format(min),
    if (f.maxTargetAmount case final max?) 'max_target_amount': Scaled.format(max),
    'target_year_from': ?f.yearFrom,
    'target_year_to': ?f.yearTo,
  };

  static Map<String, dynamic> toQuery(GoalQuery q) => {
    ...filtersToQuery(q.filters),
    if (q.search.isNotEmpty) 'q': q.search,
    'sort': q.sort.code,
    'page': q.page,
    'page_size': q.pageSize,
  };

  static Paged<Goal> pageFromJson(Map<String, dynamic> json) => Paged(
    items: [
      for (final item in json['items'] as List<dynamic>)
        GoalModel.fromJson(item as Map<String, dynamic>),
    ],
    page: json['page'] as int,
    pageSize: json['page_size'] as int,
    total: json['total'] as int,
    totalPages: json['total_pages'] as int,
  );

  static GoalsSummary summaryFromJson(Map<String, dynamic> json) => GoalsSummary(
    count: json['count'] as int,
    currency: Currency.fromCode(json['currency'] as String),
    totalMonthlySip: double.parse(json['total_monthly_sip'] as String),
    totalTarget: double.parse(json['total_target'] as String),
    converted: json['converted'] as bool,
    ratesAsOf: DateTime.parse(json['rates_as_of'] as String),
  );
}
