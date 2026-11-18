import '../../../../core/domain/currency.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/remote_call.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_query.dart';
import '../models/goal_model.dart';
import '../models/goal_query_model.dart';

class GoalsRemoteDataSource {
  GoalsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Paged<Goal>> list(GoalQuery query) => remoteObject(
    () => _api.get(Endpoints.goals, query: GoalQueryModel.toQuery(query)),
    GoalQueryModel.pageFromJson,
  );

  Future<GoalsSummary> summary(GoalFilters filters, Currency inCurrency) => remoteObject(
    () => _api.get(
      Endpoints.goalsSummary,
      query: {...GoalQueryModel.filtersToQuery(filters), 'in_currency': inCurrency.code},
    ),
    GoalQueryModel.summaryFromJson,
  );

  Future<Goal> get(String id) =>
      remoteObject(() => _api.get(Endpoints.goal(id)), GoalModel.fromJson);

  Future<Goal> create(GoalDraft draft) => remoteObject(
    () => _api.post(Endpoints.goals, body: GoalModel.toJson(draft, includeCurrency: true)),
    GoalModel.fromJson,
  );

  Future<Goal> update(String id, GoalDraft draft) => remoteObject(
    () => _api.patch(Endpoints.goal(id), body: GoalModel.toJson(draft, includeCurrency: false)),
    GoalModel.fromJson,
  );

  Future<void> delete(String id) => remoteVoid(() => _api.delete(Endpoints.goal(id)));
}
