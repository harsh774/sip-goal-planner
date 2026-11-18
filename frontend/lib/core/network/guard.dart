import '../error/failure.dart';
import '../error/result.dart';
import 'api_exception.dart';

/// Runs a data-layer call and converts API errors into a [Result]. Datasources
/// already turn malformed payloads into [ApiException]s; the rest is a safety net.
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Success(await body());
  } on ApiException catch (e) {
    return Err(e.toFailure());
  } on FormatException {
    return const Err(ServerFailure());
  } on TypeError {
    return const Err(ServerFailure());
  }
}
