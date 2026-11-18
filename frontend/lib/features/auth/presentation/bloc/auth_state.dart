part of 'auth_bloc.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.submitting = false,
    this.failure,
  });

  final AuthStatus status;
  final User? user;
  final bool submitting;
  final Failure? failure;

  AuthState copyWith({User? user, bool? submitting, Failure? failure, bool clearFailure = false}) =>
      AuthState(
        status: status,
        user: user ?? this.user,
        submitting: submitting ?? this.submitting,
        failure: clearFailure ? null : failure ?? this.failure,
      );

  @override
  List<Object?> get props => [status, user, submitting, failure];
}
