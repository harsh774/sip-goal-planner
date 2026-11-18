import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/slow_notice.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../projection/domain/usecases/calculate_goal_totals.dart';
import '../../domain/entities/goal.dart';
import '../../domain/usecases/goal_usecases.dart';

sealed class GoalListEvent extends Equatable {
  const GoalListEvent();

  @override
  List<Object?> get props => [];
}

final class GoalsRequested extends GoalListEvent {
  const GoalsRequested(this.totalCurrency);

  final Currency totalCurrency;

  @override
  List<Object?> get props => [totalCurrency];
}

final class TotalCurrencyChanged extends GoalListEvent {
  const TotalCurrencyChanged(this.currency);

  final Currency currency;

  @override
  List<Object?> get props => [currency];
}

sealed class GoalListState extends Equatable {
  const GoalListState();

  @override
  List<Object?> get props => [];
}

final class GoalListLoading extends GoalListState {
  const GoalListLoading({this.isSlow = false});

  final bool isSlow;

  @override
  List<Object?> get props => [isSlow];
}

final class GoalListEmpty extends GoalListState {
  const GoalListEmpty();
}

final class GoalListLoaded extends GoalListState {
  const GoalListLoaded(this.goals, this.overview);

  final List<Goal> goals;
  final GoalOverview overview;

  @override
  List<Object?> get props => [goals, overview];
}

final class GoalListError extends GoalListState {
  const GoalListError(this.failure, this.totalCurrency);

  final Failure failure;
  final Currency totalCurrency;

  @override
  List<Object?> get props => [failure, totalCurrency];
}

class GoalListBloc extends Bloc<GoalListEvent, GoalListState> {
  GoalListBloc({
    required GetGoals getGoals,
    required CalculateGoalTotals calculateTotals,
    Duration slowAfter = const Duration(seconds: 3),
  }) : _getGoals = getGoals,
       _calculateTotals = calculateTotals,
       _slowAfter = slowAfter,
       super(const GoalListLoading()) {
    on<GoalsRequested>(_onRequested, transformer: restartable());
    on<TotalCurrencyChanged>(_onCurrencyChanged);
  }

  final GetGoals _getGoals;
  final CalculateGoalTotals _calculateTotals;
  final Duration _slowAfter;

  Future<void> _onRequested(GoalsRequested event, Emitter<GoalListState> emit) async {
    emit(const GoalListLoading());
    final result = await withSlowNotice(
      _getGoals(const NoParams()),
      () => emit(const GoalListLoading(isSlow: true)),
      after: _slowAfter,
    );
    emit(switch (result) {
      Success(value: final goals) when goals.isEmpty => const GoalListEmpty(),
      Success(value: final goals) => GoalListLoaded(
        goals,
        _calculateTotals(goals, event.totalCurrency),
      ),
      Err(:final failure) => GoalListError(failure, event.totalCurrency),
    });
  }

  void _onCurrencyChanged(TotalCurrencyChanged event, Emitter<GoalListState> emit) {
    if (state case GoalListLoaded(:final goals)) {
      emit(GoalListLoaded(goals, _calculateTotals(goals, event.currency)));
    }
  }
}
