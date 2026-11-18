import '../../../../core/error/result.dart';
import '../entities/goal.dart';

abstract interface class GoalsRepository {
  Future<Result<List<Goal>>> list();

  Future<Result<Goal>> get(String id);

  Future<Result<Goal>> create(GoalDraft draft);

  /// Sends every editable field; the server records only what changed.
  Future<Result<Goal>> update(String id, GoalDraft draft);

  Future<Result<void>> delete(String id);
}
