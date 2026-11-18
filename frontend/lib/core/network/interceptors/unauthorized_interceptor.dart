import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';
import '../session_events.dart';

/// A 401 on an authenticated request means the token is no longer valid.
/// (A 401 from the login form itself is just a wrong password, so it's ignored.)
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(this._tokens, this._session);

  final TokenStorage _tokens;
  final SessionEvents _session;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && sentToken) {
      await _tokens.clear();
      _session.expire();
    }
    handler.next(err);
  }
}
