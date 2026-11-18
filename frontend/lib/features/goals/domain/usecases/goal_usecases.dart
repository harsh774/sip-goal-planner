import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/domain/currency.dart';
import '../entities/goal.dart';
import '../entities/goal_query.dart';
import '../repositories/goals_repository.dart';

class GetGoals implements UseCase<Paged<Goal>, GoalQuery> {
  GetGoals(this._repo);

  final GoalsRepository _repo;

  @override
  Future<Result<Paged<Goal>>> call(GoalQuery query) => _repo.list(query);
}

class SummaryParams {
  const SummaryParams(this.filters, this.inCurrency);

  final GoalFilters filters;
  final Currency inCurrency;
}

class GetGoalsSummary implements UseCase<GoalsSummary, SummaryParams> {
  GetGoalsSummary(this._repo);

  final GoalsRepository _repo;

  @override
  Future<Result<GoalsSummary>> call(SummaryParams p) => _repo.summary(p.filters, p.inCurrency);
}

class GetGoal implements UseCase<Goal, String> {
  GetGoal(this._repo);

  final GoalsRepository _repo;

  @override
  Future<Result<Goal>> call(String id) => _repo.get(id);
}

class SaveGoalParams {
  const SaveGoalParams(this.draft, {this.id});

  final GoalDraft draft;

  /// Null creates a new goal.
  final String? id;
}

class SaveGoal implements UseCase<Goal, SaveGoalParams> {
  SaveGoal(this._repo);

  final GoalsRepository _repo;

  @override
  Future<Result<Goal>> call(SaveGoalParams p) =>
      p.id == null ? _repo.create(p.draft) : _repo.update(p.id!, p.draft);
}

class DeleteGoal implements UseCase<void, String> {
  DeleteGoal(this._repo);

  final GoalsRepository _repo;

  @override
  Future<Result<void>> call(String id) => _repo.delete(id);
}
