import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import '../security/encryption_settings.dart';
import '../security/transport_key_source.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/encryption_interceptor.dart';
import 'interceptors/unauthorized_interceptor.dart';
import 'session_events.dart';

Dio buildDio({
  required String baseUrl,
  required TokenStorage tokens,
  required SessionEvents session,
  required EncryptionSettings encryption,
  required TransportKeySource transportKeys,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  dio.interceptors.addAll([
    // First, so responses are opened before the others look at them.
    EncryptionInterceptor(dio, encryption, transportKeys),
    AuthInterceptor(tokens),
    UnauthorizedInterceptor(tokens, session),
    if (kDebugMode) LogInterceptor(requestBody: true, responseBody: false),
  ]);
  return dio;
}
