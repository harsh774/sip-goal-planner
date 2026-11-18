import 'api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

/// Runs a request in a datasource and parses its JSON object. API errors pass
/// through; a missing or malformed body becomes [MalformedResponseApiException].
Future<T> remoteObject<T>(Future<Object?> Function() send, T Function(JsonMap) parse) async {
  try {
    final json = await send();
    if (json is! JsonMap) throw MalformedResponseApiException(json);
    return parse(json);
  } on ApiException {
    rethrow;
  } on Exception catch (e) {
    throw MalformedResponseApiException(e);
  } on TypeError catch (e) {
    // A field had the wrong type, e.g. a number where a string was expected.
    throw MalformedResponseApiException(e);
  }
}

/// Runs a request whose response body is not needed (204s, deletes).
Future<void> remoteVoid(Future<Object?> Function() send) async {
  try {
    await send();
  } on ApiException {
    rethrow;
  } on Exception catch (e) {
    throw MalformedResponseApiException(e);
  }
}
