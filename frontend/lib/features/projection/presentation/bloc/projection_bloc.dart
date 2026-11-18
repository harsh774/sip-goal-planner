import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/slow_notice.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/usecases/goal_usecases.dart';
import '../../domain/entities/projection.dart';
import '../../domain/usecases/calculate_projection.dart';

enum PlanMode { level, stepUp }

sealed class ProjectionEvent {
  const ProjectionEvent();
}

final class ProjectionRequested extends ProjectionEvent {
  const ProjectionRequested(this.goalId);

  final String goalId;
}

final class PlanModeToggled extends ProjectionEvent {
  const PlanModeToggled(this.mode);

  final PlanMode mode;
}

final class GoalDeleteRequested extends ProjectionEvent {
  const GoalDeleteRequested();
}

sealed class ProjectionState extends Equatable {
  const ProjectionState();

  @override
  List<Object?> get props => [];
}

final class ProjectionLoading extends ProjectionState {
  const ProjectionLoading({this.isSlow = false});

  final bool isSlow;

  @override
  List<Object?> get props => [isSlow];
}

final class ProjectionLoaded extends ProjectionState {
  const ProjectionLoaded({
    required this.goal,
    required this.projection,
    this.mode = PlanMode.level,
    this.deleting = false,
    this.deleteFailure,
  });

  final Goal goal;
  final Projection projection;
  final PlanMode mode;
  final bool deleting;
  final Failure? deleteFailure;

  Plan get selectedPlan => mode == PlanMode.level ? projection.level : projection.stepUp;

  ProjectionLoaded copyWith({PlanMode? mode, bool? deleting, Failure? deleteFailure}) =>
      ProjectionLoaded(
        goal: goal,
        projection: projection,
        mode: mode ?? this.mode,
        deleting: deleting ?? this.deleting,
        deleteFailure: deleteFailure,
      );

  @override
  List<Object?> get props => [goal, projection, mode, deleting, deleteFailure];
}

final class ProjectionError extends ProjectionState {
  const ProjectionError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class GoalDeleted extends ProjectionState {
  const GoalDeleted();
}

class ProjectionBloc extends Bloc<ProjectionEvent, ProjectionState> {
  ProjectionBloc({
    required GetGoal getGoal,
    required DeleteGoal deleteGoal,
    required CalculateProjection calculate,
    Duration slowAfter = const Duration(seconds: 3),
  }) : _getGoal = getGoal,
       _deleteGoal = deleteGoal,
       _calculate = calculate,
       _slowAfter = slowAfter,
       super(const ProjectionLoading()) {
    on<ProjectionRequested>(_onRequested, transformer: restartable());
    on<PlanModeToggled>(_onModeToggled);
    on<GoalDeleteRequested>(_onDelete, transformer: droppable());
  }

  final GetGoal _getGoal;
  final DeleteGoal _deleteGoal;
  final CalculateProjection _calculate;
  final Duration _slowAfter;

  Future<void> _onRequested(ProjectionRequested event, Emitter<ProjectionState> emit) async {
    emit(const ProjectionLoading());
    final result = await withSlowNotice(
      _getGoal(event.goalId),
      () => emit(const ProjectionLoading(isSlow: true)),
      after: _slowAfter,
    );
    emit(switch (result) {
      Success(value: final goal) => ProjectionLoaded(
        goal: goal,
        projection: _calculate(goal.toDraft()),
      ),
      Err(:final failure) => ProjectionError(failure),
    });
  }

  void _onModeToggled(PlanModeToggled event, Emitter<ProjectionState> emit) {
    if (state case final ProjectionLoaded loaded) emit(loaded.copyWith(mode: event.mode));
  }

  Future<void> _onDelete(GoalDeleteRequested event, Emitter<ProjectionState> emit) async {
    final loaded = state;
    if (loaded is! ProjectionLoaded) return;
    emit(loaded.copyWith(deleting: true));
    final result = await _deleteGoal(loaded.goal.id);
    emit(switch (result) {
      Success() => const GoalDeleted(),
      Err(:final failure) => loaded.copyWith(deleting: false, deleteFailure: failure),
    });
  }
}
