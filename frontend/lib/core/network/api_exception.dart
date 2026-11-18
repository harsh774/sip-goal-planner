import '../error/failure.dart';

/// Thrown by [ApiClient]. Never leaves the data layer: repositories convert it
/// to a [Failure] with [toFailure].
sealed class ApiException implements Exception {
  const ApiException();

  Failure toFailure();
}

final class TimeoutApiException extends ApiException {
  const TimeoutApiException();

  @override
  Failure toFailure() => const NetworkFailure(timeout: true);
}

final class NetworkApiException extends ApiException {
  const NetworkApiException();

  @override
  Failure toFailure() => const NetworkFailure();
}

final class UnauthorizedApiException extends ApiException {
  const UnauthorizedApiException(this.message);

  final String? message;

  @override
  Failure toFailure() => switch (message) {
    final m? => AuthFailure(m),
    null => const AuthFailure(),
  };
}

final class NotFoundApiException extends ApiException {
  const NotFoundApiException(this.message);

  final String? message;

  @override
  Failure toFailure() => switch (message) {
    final m? => NotFoundFailure(m),
    null => const NotFoundFailure(),
  };
}

/// 409 and 422 responses with `{"detail": [{"field", "code", "message"}]}`.
final class ValidationApiException extends ApiException {
  const ValidationApiException(this.fieldErrors);

  final Map<String?, FieldIssue> fieldErrors;

  @override
  Failure toFailure() => ValidationFailure(fieldErrors);
}

final class ServerApiException extends ApiException {
  const ServerApiException(this.statusCode);

  final int? statusCode;

  @override
  Failure toFailure() => const ServerFailure();
}

/// The server answered, but not with the shape the app expects.
final class MalformedResponseApiException extends ApiException {
  const MalformedResponseApiException([this.cause]);

  final Object? cause;

  @override
  Failure toFailure() => const ServerFailure();
}
