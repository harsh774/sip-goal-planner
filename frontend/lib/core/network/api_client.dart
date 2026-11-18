import 'dart:async';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'api_exception.dart';

/// The only way datasources talk to the API. Returns decoded JSON or throws an
/// [ApiException]; callers never see Dio types.
class ApiClient {
  ApiClient(this._dio, {Duration timeout = const Duration(seconds: 15)}) : _timeout = timeout;

  final Dio _dio;
  final Duration _timeout;

  Future<Object?> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query));

  Future<Object?> post(String path, {Object? body}) =>
      _send(() => _dio.post<Object?>(path, data: body));

  Future<Object?> postForm(String path, Map<String, String> fields) => _send(
    () => _dio.post<Object?>(
      path,
      data: fields,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    ),
  );

  Future<Object?> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<Object?>(path, data: body));

  Future<void> delete(String path) => _send(() => _dio.delete<Object?>(path));

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      // Dio's connect timeout is unreliable on web, so every call gets an overall cap.
      final response = await request().timeout(_timeout);
      return response.data;
    } on TimeoutException {
      throw const TimeoutApiException();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static ApiException _map(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const TimeoutApiException(),
    DioExceptionType.badResponse => _fromResponse(e.response),
    _ => e.response == null ? const NetworkApiException() : _fromResponse(e.response),
  };

  static ApiException _fromResponse(Response<Object?>? response) {
    final detail = switch (response?.data) {
      {'detail': final Object? d} => d,
      _ => null,
    };
    return switch (response?.statusCode) {
      401 => UnauthorizedApiException(detail is String ? detail : null),
      404 => NotFoundApiException(detail is String ? detail : null),
      409 || 422 when detail is List => ValidationApiException(_fieldErrors(detail)),
      final code => ServerApiException(code),
    };
  }

  static Map<String?, FieldIssue> _fieldErrors(List<Object?> detail) => {
    for (final item in detail)
      if (item case {'code': final String code, 'message': final String message})
        (item['field'] as String?): FieldIssue(code, message),
  };
}
