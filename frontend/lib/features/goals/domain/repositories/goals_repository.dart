import '../../../../core/error/result.dart';
import '../../../../core/domain/currency.dart';
import '../entities/goal.dart';
import '../entities/goal_query.dart';

abstract interface class GoalsRepository {
  Future<Result<Paged<Goal>>> list(GoalQuery query);

  /// Totals across every goal matching [filters], added up in [inCurrency].
  Future<Result<GoalsSummary>> summary(GoalFilters filters, Currency inCurrency);

  Future<Result<Goal>> get(String id);

  Future<Result<Goal>> create(GoalDraft draft);

  /// Sends every editable field; the server records only what changed.
  Future<Result<Goal>> update(String id, GoalDraft draft);

  Future<Result<void>> delete(String id);
}
