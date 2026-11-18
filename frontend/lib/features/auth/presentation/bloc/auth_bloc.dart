import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/currency.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/session_events.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/auth_usecases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required GetCurrentUser getCurrentUser,
    required Login login,
    required Register register,
    required Logout logout,
    required UpdateDefaultCurrency updateDefaultCurrency,
    required SessionEvents session,
  }) : _getCurrentUser = getCurrentUser,
       _login = login,
       _register = register,
       _logout = logout,
       _updateDefaultCurrency = updateDefaultCurrency,
       super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin, transformer: droppable());
    on<AuthRegisterRequested>(_onRegister, transformer: droppable());
    on<AuthLogoutRequested>(_onLogout);
    on<AuthDefaultCurrencyChanged>(_onCurrencyChanged);
    on<AuthFailureCleared>((_, emit) => emit(state.copyWith(clearFailure: true)));
    on<_AuthSessionExpired>(_onSessionExpired);
    _sessionSub = session.expired.listen((_) => add(const _AuthSessionExpired()));
  }

  final GetCurrentUser _getCurrentUser;
  final Login _login;
  final Register _register;
  final Logout _logout;
  final UpdateDefaultCurrency _updateDefaultCurrency;
  late final StreamSubscription<void> _sessionSub;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _getCurrentUser(const NoParams());
    emit(switch (result) {
      Success(value: final User user) => AuthState(status: AuthStatus.authenticated, user: user),
      _ => const AuthState(status: AuthStatus.unauthenticated),
    });
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) =>
      _submit(emit, () => _login(Credentials(event.email, event.password)));

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) =>
      _submit(emit, () => _register(Credentials(event.email, event.password)));

  Future<void> _submit(Emitter<AuthState> emit, Future<Result<User>> Function() action) async {
    emit(state.copyWith(submitting: true, clearFailure: true));
    final result = await action();
    emit(switch (result) {
      Success(value: final user) => AuthState(status: AuthStatus.authenticated, user: user),
      Err(:final failure) => state.copyWith(submitting: false, failure: failure),
    });
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _logout(const NoParams());
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onCurrencyChanged(AuthDefaultCurrencyChanged event, Emitter<AuthState> emit) async {
    final result = await _updateDefaultCurrency(event.currency);
    if (result case Success(value: final user)) emit(state.copyWith(user: user));
  }

  void _onSessionExpired(_AuthSessionExpired event, Emitter<AuthState> emit) {
    if (state.status != AuthStatus.authenticated) return;
    emit(const AuthState(status: AuthStatus.unauthenticated, failure: AuthFailure()));
  }

  @override
  Future<void> close() async {
    await _sessionSub.cancel();
    return super.close();
  }
}
