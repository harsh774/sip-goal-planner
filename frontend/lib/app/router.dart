import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/goals/domain/entities/goal_type.dart';
import '../features/goals/presentation/pages/goal_form_page.dart';
import '../features/goals/presentation/pages/goal_list_page.dart';
import '../features/projection/presentation/pages/goal_plan_page.dart';
import '../shared/widgets/splash_page.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const goals = '/goals';
  static const newGoal = '/goals/new';

  static String goal(String id) => '/goals/$id';
  static String editGoal(String id) => '/goals/$id/edit';
}

GoRouter buildRouter(AuthBloc auth) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _StreamListenable(auth.stream),
    redirect: (context, state) {
      final status = auth.state.status;
      final location = state.matchedLocation;
      final onAuthPage = location == Routes.login || location == Routes.register;

      return switch (status) {
        AuthStatus.unknown => location == Routes.splash ? null : Routes.splash,
        AuthStatus.unauthenticated => onAuthPage ? null : Routes.login,
        AuthStatus.authenticated => onAuthPage || location == Routes.splash ? Routes.goals : null,
      };
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const AuthPage(mode: AuthMode.login),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, _) => const AuthPage(mode: AuthMode.register),
      ),
      GoRoute(
        path: Routes.goals,
        builder: (_, _) => const GoalListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, state) => GoalFormPage(
              template: switch (state.uri.queryParameters['type']) {
                final String code => GoalType.values.where((t) => t.code == code).firstOrNull,
                null => null,
              },
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => GoalPlanPage(goalId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => GoalFormPage(goalId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
