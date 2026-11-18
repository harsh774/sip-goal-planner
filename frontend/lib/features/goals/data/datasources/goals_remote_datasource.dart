import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/domain/currency.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_query.dart';
import '../models/goal_query_model.dart';
import '../models/goal_model.dart';

class GoalsRemoteDataSource {
  GoalsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Paged<Goal>> list(GoalQuery query) async {
    final json = await _api.get(Endpoints.goals, query: GoalQueryModel.toQuery(query));
    return GoalQueryModel.pageFromJson(json! as Map<String, dynamic>);
  }

  Future<GoalsSummary> summary(GoalFilters filters, Currency inCurrency) async {
    final json = await _api.get(
      Endpoints.goalsSummary,
      query: {...GoalQueryModel.filtersToQuery(filters), 'in_currency': inCurrency.code},
    );
    return GoalQueryModel.summaryFromJson(json! as Map<String, dynamic>);
  }

  Future<Goal> get(String id) async =>
      GoalModel.fromJson((await _api.get(Endpoints.goal(id)))! as Map<String, dynamic>);

  Future<Goal> create(GoalDraft draft) async {
    final json = await _api.post(
      Endpoints.goals,
      body: GoalModel.toJson(draft, includeCurrency: true),
    );
    return GoalModel.fromJson(json! as Map<String, dynamic>);
  }

  Future<Goal> update(String id, GoalDraft draft) async {
    final json = await _api.patch(
      Endpoints.goal(id),
      body: GoalModel.toJson(draft, includeCurrency: false),
    );
    return GoalModel.fromJson(json! as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete(Endpoints.goal(id));
}
