import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../domain/entities/goal.dart';
import '../models/goal_model.dart';

class GoalsRemoteDataSource {
  GoalsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<Goal>> list() async {
    final json = await _api.get(Endpoints.goals);
    return [
      for (final item in json! as List<dynamic>) GoalModel.fromJson(item as Map<String, dynamic>),
    ];
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
