import 'package:equatable/equatable.dart';

class FieldIssue extends Equatable {
  const FieldIssue(this.code, this.message);

  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

sealed class Failure extends Equatable {
  const Failure();

  String get message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure({this.timeout = false});

  final bool timeout;

  @override
  String get message => timeout
      ? 'The server is taking too long to respond.'
      : 'We can’t reach the server. Check your internet connection.';

  @override
  List<Object?> get props => [timeout];
}

final class AuthFailure extends Failure {
  const AuthFailure([this.message = 'Your session has expired. Please log in again.']);

  @override
  final String message;
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([this.message = 'We couldn’t find that.']);

  @override
  final String message;
}

/// Field-level problems, keyed by API field name. A `null` key holds form-wide issues.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.fieldErrors);

  final Map<String?, FieldIssue> fieldErrors;

  @override
  String get message {
    final count = fieldErrors.length;
    return count == 1 ? fieldErrors.values.first.message : '$count fields need your attention.';
  }

  @override
  List<Object?> get props => [fieldErrors];
}

final class ServerFailure extends Failure {
  const ServerFailure();

  @override
  String get message => 'Something went wrong on our side. Please try again.';
}
