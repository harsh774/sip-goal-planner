import '../../../../core/error/result.dart';
import '../../../../core/network/guard.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goals_repository.dart';
import '../datasources/goals_remote_datasource.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  GoalsRepositoryImpl(this._remote);

  final GoalsRemoteDataSource _remote;

  @override
  Future<Result<List<Goal>>> list() => guard(_remote.list);

  @override
  Future<Result<Goal>> get(String id) => guard(() => _remote.get(id));

  @override
  Future<Result<Goal>> create(GoalDraft draft) => guard(() => _remote.create(draft));

  @override
  Future<Result<Goal>> update(String id, GoalDraft draft) => guard(() => _remote.update(id, draft));

  @override
  Future<Result<void>> delete(String id) => guard(() => _remote.delete(id));
}
