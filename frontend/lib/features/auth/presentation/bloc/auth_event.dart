part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested(this.email, this.password);

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested(this.account);

  final NewAccount account;

  @override
  List<Object?> get props => [account];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthDefaultCurrencyChanged extends AuthEvent {
  const AuthDefaultCurrencyChanged(this.currency);

  final Currency currency;

  @override
  List<Object?> get props => [currency];
}

final class AuthFailureCleared extends AuthEvent {
  const AuthFailureCleared();
}

final class _AuthSessionExpired extends AuthEvent {
  const _AuthSessionExpired();
}
