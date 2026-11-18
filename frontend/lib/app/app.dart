import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../shared/connectivity/connectivity_cubit.dart';
import '../shared/connectivity/offline_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';

const _appTitleText = 'GoalPlanner';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _auth = sl<AuthBloc>()..add(const AuthStarted());
  late final GoRouter _router = buildRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _auth),
        BlocProvider(create: (_) => sl<ConnectivityCubit>()),
      ],
      // Keeps content clear of phone status bars and notches.
      child: SafeArea(
        child: MaterialApp.router(
          title: _appTitleText,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          routerConfig: _router,
          builder: (_, child) => OfflineGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
