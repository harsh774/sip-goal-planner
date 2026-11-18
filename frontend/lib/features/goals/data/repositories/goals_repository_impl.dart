import '../../../../core/error/result.dart';
import '../../../../core/network/guard.dart';
import '../../../../core/domain/currency.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_query.dart';
import '../../domain/repositories/goals_repository.dart';
import '../datasources/goals_remote_datasource.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  GoalsRepositoryImpl(this._remote);

  final GoalsRemoteDataSource _remote;

  @override
  Future<Result<Paged<Goal>>> list(GoalQuery query) => guard(() => _remote.list(query));

  @override
  Future<Result<GoalsSummary>> summary(GoalFilters filters, Currency inCurrency) =>
      guard(() => _remote.summary(filters, inCurrency));

  @override
  Future<Result<Goal>> get(String id) => guard(() => _remote.get(id));

  @override
  Future<Result<Goal>> create(GoalDraft draft) => guard(() => _remote.create(draft));

  @override
  Future<Result<Goal>> update(String id, GoalDraft draft) => guard(() => _remote.update(id, draft));

  @override
  Future<Result<void>> delete(String id) => guard(() => _remote.delete(id));
}
