import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/unauthorized_interceptor.dart';
import 'session_events.dart';

Dio buildDio({
  required String baseUrl,
  required TokenStorage tokens,
  required SessionEvents session,
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
    AuthInterceptor(tokens),
    UnauthorizedInterceptor(tokens, session),
    if (kDebugMode) LogInterceptor(requestBody: true, responseBody: false),
  ]);
  return dio;
}
