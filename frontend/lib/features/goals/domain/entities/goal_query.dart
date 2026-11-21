import 'package:equatable/equatable.dart';

import '../../../../core/domain/currency.dart';
import 'goal_type.dart';

enum GoalSort {
  newest('newest', 'Newest first'),
  targetDate('target_date', 'Reaching soonest'),
  targetAmount('target_amount', 'Largest target');

  const GoalSort(this.code, this.label);

  final String code;
  final String label;
}

/// Server-side filters for the goal list and summary. Amounts are in hundredths of
/// [currency]; an amount range only applies together with a currency.
class GoalFilters extends Equatable {
  const GoalFilters({
    this.currency,
    this.type,
    this.minTargetAmount,
    this.maxTargetAmount,
    this.yearFrom,
    this.yearTo,
  });

  static const none = GoalFilters();

  final Currency? currency;
  final GoalType? type;
  final int? minTargetAmount;
  final int? maxTargetAmount;
  final int? yearFrom;
  final int? yearTo;

  bool get isEmpty => this == none;

  @override
  List<Object?> get props => [currency, type, minTargetAmount, maxTargetAmount, yearFrom, yearTo];
}

class GoalQuery extends Equatable {
  const GoalQuery({
    this.filters = GoalFilters.none,
    this.search = '',
    this.sort = GoalSort.newest,
    this.page = 1,
    this.pageSize = 10,
    this.excludeCompleted = false,
  });

  final GoalFilters filters;

  /// Matches goal names containing this text; empty means no search.
  final String search;
  final GoalSort sort;
  final int page;
  final int pageSize;

  /// Leaves out completed goals, e.g. for "Reaching soon".
  final bool excludeCompleted;

  GoalQuery copyWith({GoalFilters? filters, String? search, GoalSort? sort, int? page}) =>
      GoalQuery(
        filters: filters ?? this.filters,
        search: search ?? this.search,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        pageSize: pageSize,
        excludeCompleted: excludeCompleted,
      );

  @override
  List<Object?> get props => [filters, search, sort, page, pageSize, excludeCompleted];
}

class Paged<T> extends Equatable {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  Paged<R> map<R>(R Function(T) convert) => Paged(
    items: items.map(convert).toList(),
    page: page,
    pageSize: pageSize,
    total: total,
    totalPages: totalPages,
  );

  @override
  List<Object?> get props => [items, page, pageSize, total, totalPages];
}

/// Totals across every goal matching a filter, computed by the server.
class GoalsSummary extends Equatable {
  const GoalsSummary({
    required this.count,
    required this.currency,
    required this.totalMonthlySip,
    required this.totalTarget,
    required this.converted,
    required this.ratesAsOf,
  });

  final int count;
  final Currency currency;
  final double totalMonthlySip;
  final double totalTarget;

  /// True when goals in other currencies were converted, so totals are approximate.
  final bool converted;
  final DateTime ratesAsOf;

  @override
  List<Object?> get props => [count, currency, totalMonthlySip, totalTarget, converted, ratesAsOf];
}
