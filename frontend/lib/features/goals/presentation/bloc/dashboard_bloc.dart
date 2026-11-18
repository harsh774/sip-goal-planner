import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/event_transformers.dart';
import '../../../../core/presentation/slow_notice.dart';
import '../../../projection/domain/usecases/plan_goals.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_query.dart';
import '../../domain/usecases/goal_usecases.dart';

sealed class DashboardEvent {
  const DashboardEvent();
}

/// First load, and reloads after returning from another screen.
final class DashboardRequested extends DashboardEvent {
  const DashboardRequested(this.totalCurrency);

  final Currency totalCurrency;
}

final class DashboardFiltersChanged extends DashboardEvent {
  const DashboardFiltersChanged(this.filters);

  final GoalFilters filters;
}

/// Typed in the search box; debounced so the API is called once typing pauses.
final class DashboardSearchChanged extends DashboardEvent {
  const DashboardSearchChanged(this.text);

  final String text;
}

final class DashboardSortChanged extends DashboardEvent {
  const DashboardSortChanged(this.sort);

  final GoalSort sort;
}

final class DashboardPageChanged extends DashboardEvent {
  const DashboardPageChanged(this.page);

  final int page;
}

final class DashboardTotalCurrencyChanged extends DashboardEvent {
  const DashboardTotalCurrencyChanged(this.currency);

  final Currency currency;
}

enum DashboardStatus { loading, ready, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.isSlow = false,
    this.query = const GoalQuery(),
    this.totalCurrency = Currency.inr,
    this.reachingSoon = const [],
    this.page,
    this.summary,
    this.listLoading = false,
    this.failure,
  });

  final DashboardStatus status;
  final bool isSlow;
  final GoalQuery query;
  final Currency totalCurrency;

  /// The few goals with the nearest target date, regardless of filters.
  final List<GoalPlan> reachingSoon;
  final Paged<GoalPlan>? page;
  final GoalsSummary? summary;

  /// A page, filter or sort change is in flight; the current list stays visible.
  final bool listLoading;
  final Failure? failure;

  bool get hasNoGoals => status == DashboardStatus.ready && reachingSoon.isEmpty;

  DashboardState copyWith({
    DashboardStatus? status,
    bool? isSlow,
    GoalQuery? query,
    Currency? totalCurrency,
    List<GoalPlan>? reachingSoon,
    Paged<GoalPlan>? page,
    GoalsSummary? summary,
    bool? listLoading,
    Failure? failure,
    bool clearFailure = false,
  }) => DashboardState(
    status: status ?? this.status,
    isSlow: isSlow ?? this.isSlow,
    query: query ?? this.query,
    totalCurrency: totalCurrency ?? this.totalCurrency,
    reachingSoon: reachingSoon ?? this.reachingSoon,
    page: page ?? this.page,
    summary: summary ?? this.summary,
    listLoading: listLoading ?? this.listLoading,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => [
    status,
    isSlow,
    query,
    totalCurrency,
    reachingSoon,
    page,
    summary,
    listLoading,
    failure,
  ];
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetGoals getGoals,
    required GetGoalsSummary getSummary,
    required PlanGoals planGoals,
    this.reachingSoonCount = 3,
    this.searchDebounce = const Duration(milliseconds: 300),
    Duration slowAfter = const Duration(seconds: 3),
  }) : _getGoals = getGoals,
       _getSummary = getSummary,
       _planGoals = planGoals,
       _slowAfter = slowAfter,
       super(const DashboardState()) {
    on<DashboardRequested>(_onRequested, transformer: restartable());
    on<DashboardFiltersChanged>(
      (e, emit) => _reloadList(emit, state.query.copyWith(filters: e.filters, page: 1)),
      transformer: restartable(),
    );
    on<DashboardSearchChanged>((e, emit) {
      final search = e.text.trim();
      if (search == state.query.search) return null;
      return _reloadList(emit, state.query.copyWith(search: search, page: 1));
    }, transformer: debounceRestartable(searchDebounce));
    on<DashboardSortChanged>(
      (e, emit) => _reloadList(emit, state.query.copyWith(sort: e.sort, page: 1)),
      transformer: restartable(),
    );
    on<DashboardPageChanged>(
      (e, emit) => _reloadList(emit, state.query.copyWith(page: e.page)),
      transformer: restartable(),
    );
    on<DashboardTotalCurrencyChanged>(_onCurrencyChanged, transformer: restartable());
  }

  final int reachingSoonCount;
  final Duration searchDebounce;
  final GetGoals _getGoals;
  final GetGoalsSummary _getSummary;
  final PlanGoals _planGoals;
  final Duration _slowAfter;

  Future<void> _onRequested(DashboardRequested event, Emitter<DashboardState> emit) async {
    final firstLoad = state.status != DashboardStatus.ready;
    emit(
      state.copyWith(
        status: firstLoad ? DashboardStatus.loading : null,
        isSlow: false,
        totalCurrency: event.totalCurrency,
        listLoading: !firstLoad,
        clearFailure: true,
      ),
    );

    final results = await withSlowNotice(
      Future.wait<Result<Object>>([
        _getGoals(GoalQuery(sort: GoalSort.targetDate, pageSize: reachingSoonCount)),
        _getGoals(state.query),
        _getSummary(SummaryParams(GoalFilters.none, event.totalCurrency)),
      ]),
      () => emit(state.copyWith(isSlow: true)),
      after: _slowAfter,
    );

    if (results.whereType<Err<Object>>().firstOrNull case Err(:final failure)) {
      emit(
        state.copyWith(
          status: firstLoad ? DashboardStatus.failure : null,
          listLoading: false,
          failure: failure,
        ),
      );
      return;
    }
    final [soon, page, summary] = [for (final r in results) (r as Success<Object>).value];
    emit(
      state.copyWith(
        status: DashboardStatus.ready,
        isSlow: false,
        listLoading: false,
        reachingSoon: _planGoals((soon as Paged<Goal>).items),
        page: (page as Paged<Goal>).map(_plan),
        summary: summary as GoalsSummary,
      ),
    );
  }

  /// Filters, sort and paging change only the list; the totals always cover every goal.
  Future<void> _reloadList(Emitter<DashboardState> emit, GoalQuery query) async {
    emit(state.copyWith(query: query, listLoading: true, clearFailure: true));
    emit(switch (await _getGoals(query)) {
      Success(value: final page) => state.copyWith(page: page.map(_plan), listLoading: false),
      Err(:final failure) => state.copyWith(listLoading: false, failure: failure),
    });
  }

  Future<void> _onCurrencyChanged(
    DashboardTotalCurrencyChanged event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(totalCurrency: event.currency));
    final result = await _getSummary(SummaryParams(GoalFilters.none, event.currency));
    if (result case Success(value: final summary)) emit(state.copyWith(summary: summary));
  }

  GoalPlan _plan(Goal goal) => _planGoals([goal]).single;
}
