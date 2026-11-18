import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/domain/scaled.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_type.dart';
import '../../domain/usecases/goal_usecases.dart';
import '../../domain/validation/goal_form_validator.dart';

sealed class GoalFormEvent {
  const GoalFormEvent();
}

final class GoalFormStarted extends GoalFormEvent {
  const GoalFormStarted({required this.defaultCurrency, this.goalId, this.template});

  final Currency defaultCurrency;

  /// Set when editing an existing goal.
  final String? goalId;
  final GoalType? template;
}

final class GoalFormChanged extends GoalFormEvent {
  const GoalFormChanged(this.input);

  final GoalFormInput input;
}

final class GoalFormSubmitted extends GoalFormEvent {
  const GoalFormSubmitted();
}

enum GoalFormStatus { loading, loadFailed, editing, saving, saved }

final class GoalFormState extends Equatable {
  const GoalFormState({
    required this.status,
    this.goalId,
    this.input,
    this.validation,
    this.showErrors = false,
    this.serverErrors = const {},
    this.failure,
    this.saved,
  });

  final GoalFormStatus status;
  final String? goalId;
  final GoalFormInput? input;
  final GoalValidation? validation;

  /// Client-side errors are shown only after the first submit attempt.
  final bool showErrors;
  final Map<String, String> serverErrors;
  final Failure? failure;
  final Goal? saved;

  bool get isEdit => goalId != null;

  Map<String, String> get visibleErrors => {
    if (showErrors) ...?validation?.errors,
    ...serverErrors,
  };

  GoalFormState copyWith({
    GoalFormStatus? status,
    GoalFormInput? input,
    GoalValidation? validation,
    bool? showErrors,
    Map<String, String>? serverErrors,
    Failure? failure,
    bool clearFailure = false,
    Goal? saved,
  }) => GoalFormState(
    status: status ?? this.status,
    goalId: goalId,
    input: input ?? this.input,
    validation: validation ?? this.validation,
    showErrors: showErrors ?? this.showErrors,
    serverErrors: serverErrors ?? this.serverErrors,
    failure: clearFailure ? null : failure ?? this.failure,
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    status,
    goalId,
    input,
    validation,
    showErrors,
    serverErrors,
    failure,
    saved,
  ];
}

class GoalFormBloc extends Bloc<GoalFormEvent, GoalFormState> {
  GoalFormBloc({required GetGoal getGoal, required SaveGoal saveGoal, DateTime Function()? clock})
    : _getGoal = getGoal,
      _saveGoal = saveGoal,
      _clock = clock ?? DateTime.now,
      super(const GoalFormState(status: GoalFormStatus.loading)) {
    on<GoalFormStarted>(_onStarted);
    on<GoalFormChanged>(_onChanged);
    on<GoalFormSubmitted>(_onSubmitted, transformer: droppable());
  }

  final GetGoal _getGoal;
  final SaveGoal _saveGoal;
  final DateTime Function() _clock;

  Future<void> _onStarted(GoalFormStarted event, Emitter<GoalFormState> emit) async {
    final id = event.goalId;
    if (id == null) {
      final input = _blankInput(event.defaultCurrency, event.template);
      emit(
        GoalFormState(status: GoalFormStatus.editing, input: input, validation: _validate(input)),
      );
      return;
    }
    emit(GoalFormState(status: GoalFormStatus.loading, goalId: id));
    final result = await _getGoal(id);
    switch (result) {
      case Success(value: final goal):
        final input = _inputFrom(goal);
        emit(
          GoalFormState(
            status: GoalFormStatus.editing,
            goalId: id,
            input: input,
            validation: _validate(input),
          ),
        );
      case Err(:final failure):
        emit(GoalFormState(status: GoalFormStatus.loadFailed, goalId: id, failure: failure));
    }
  }

  void _onChanged(GoalFormChanged event, Emitter<GoalFormState> emit) {
    emit(
      state.copyWith(
        input: event.input,
        validation: _validate(event.input),
        serverErrors: const {},
        clearFailure: true,
      ),
    );
  }

  Future<void> _onSubmitted(GoalFormSubmitted event, Emitter<GoalFormState> emit) async {
    final draft = state.validation?.draft;
    if (draft == null) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(state.copyWith(status: GoalFormStatus.saving, showErrors: true, clearFailure: true));
    final result = await _saveGoal(SaveGoalParams(draft, id: state.goalId));
    switch (result) {
      case Success(value: final goal):
        emit(state.copyWith(status: GoalFormStatus.saved, saved: goal));
      case Err(failure: final ValidationFailure failure):
        emit(
          state.copyWith(
            status: GoalFormStatus.editing,
            serverErrors: {
              for (final MapEntry(:key, :value) in failure.fieldErrors.entries)
                key ?? 'form': value.message,
            },
            failure: failure,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: GoalFormStatus.editing, failure: failure));
    }
  }

  GoalValidation _validate(GoalFormInput input) =>
      GoalFormValidator.validate(input, today: _clock());

  GoalFormInput _blankInput(Currency currency, GoalType? template) {
    final now = _clock();
    return GoalFormInput(
      name: template == null || template == GoalType.other ? '' : template.label,
      type: template,
      currency: currency,
      targetAmount: '',
      targetDate: template == null ? null : DateTime(now.year + 5, now.month, now.day),
      currentCorpus: '0',
      expectedReturn: '12',
      annualStepUp: '0',
      inflation: '6',
    );
  }

  static GoalFormInput _inputFrom(Goal goal) => GoalFormInput(
    name: goal.name,
    type: goal.type,
    currency: goal.currency,
    targetAmount: Scaled.formatCompact(goal.targetAmount),
    targetDate: goal.targetDate,
    currentCorpus: Scaled.formatCompact(goal.currentCorpus),
    expectedReturn: Scaled.formatCompact(goal.expectedReturnBp),
    annualStepUp: Scaled.formatCompact(goal.annualStepUpBp),
    inflation: Scaled.formatCompact(goal.inflationBp),
  );
}
