import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/goals/data/datasources/goals_remote_datasource.dart';
import '../../features/goals/data/repositories/goals_repository_impl.dart';
import '../../features/goals/domain/repositories/goals_repository.dart';
import '../../features/goals/domain/usecases/goal_usecases.dart';
import '../../features/goals/presentation/bloc/goal_form_bloc.dart';
import '../../features/goals/presentation/bloc/dashboard_bloc.dart';
import '../../features/projection/domain/usecases/calculate_projection.dart';
import '../../features/projection/domain/usecases/plan_goals.dart';
import '../../features/projection/presentation/bloc/plan_preview_cubit.dart';
import '../../features/projection/presentation/bloc/projection_bloc.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/dio_client.dart';
import '../network/session_events.dart';
import '../storage/token_storage.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  sl
    // Core
    ..registerSingleton(TokenStorage(prefs))
    ..registerSingleton(SessionEvents())
    ..registerLazySingleton(
      () => ApiClient(buildDio(baseUrl: AppConfig.apiBaseUrl, tokens: sl(), session: sl())),
    )
    // Data
    ..registerLazySingleton(() => AuthRemoteDataSource(sl()))
    ..registerLazySingleton(() => GoalsRemoteDataSource(sl()))
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl()))
    ..registerLazySingleton<GoalsRepository>(() => GoalsRepositoryImpl(sl()))
    // Domain
    ..registerLazySingleton(() => GetCurrentUser(sl()))
    ..registerLazySingleton(() => Login(sl()))
    ..registerLazySingleton(() => Register(sl()))
    ..registerLazySingleton(() => Logout(sl()))
    ..registerLazySingleton(() => UpdateDefaultCurrency(sl()))
    ..registerLazySingleton(() => GetGoals(sl()))
    ..registerLazySingleton(() => GetGoalsSummary(sl()))
    ..registerLazySingleton(() => GetGoal(sl()))
    ..registerLazySingleton(() => SaveGoal(sl()))
    ..registerLazySingleton(() => DeleteGoal(sl()))
    ..registerLazySingleton(CalculateProjection.new)
    ..registerLazySingleton(() => PlanGoals(sl()))
    // Presentation: one AuthBloc for the app, fresh blocs per screen.
    ..registerLazySingleton(
      () => AuthBloc(
        getCurrentUser: sl(),
        login: sl(),
        register: sl(),
        logout: sl(),
        updateDefaultCurrency: sl(),
        session: sl(),
      ),
    )
    ..registerFactory(() => DashboardBloc(getGoals: sl(), getSummary: sl(), planGoals: sl()))
    ..registerFactory(() => GoalFormBloc(getGoal: sl(), saveGoal: sl()))
    ..registerFactory(() => PlanPreviewCubit(sl()))
    ..registerFactory(() => ProjectionBloc(getGoal: sl(), deleteGoal: sl(), calculate: sl()));
}
