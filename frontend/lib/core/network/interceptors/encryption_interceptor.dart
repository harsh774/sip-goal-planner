import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../security/encryption_settings.dart';
import '../../security/hybrid_cipher.dart';
import '../../security/transport_key_source.dart';

/// When encryption is on, seals each request's body and query with a fresh AES
/// key wrapped for the server, and opens the sealed response (errors included).
/// A 409 key_version_stale refetches the public key and retries once.
class EncryptionInterceptor extends Interceptor {
  EncryptionInterceptor(this._dio, this._settings, this._keys);

  final Dio _dio;
  final EncryptionSettings _settings;
  final TransportKeySource _keys;

  static const _aesKey = 'enc.key';
  static const _original = 'enc.original';
  static const _retried = 'enc.retried';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_settings.value) return handler.next(options);
    try {
      final key = await _keys.current();
      final aes = HybridCipher.newAesKey();
      final method = options.method;
      final path = options.uri.path;
      options.extra[_original] = (options.data, options.queryParameters, options.contentType);

      if (options.data case final Object data) {
        final isForm = options.contentType == Headers.formUrlEncodedContentType;
        final raw = isForm && data is Map<String, dynamic>
            ? Transformer.urlEncodeMap(data)
            : jsonEncode(data);
        options
          ..headers['X-Enc-Content-Type'] = options.contentType ?? Headers.jsonContentType
          ..data = HybridCipher.seal(aes, utf8.encode(raw), HybridCipher.requestAad(method, path))
          ..contentType = 'text/plain';
      }
      if (options.queryParameters.isNotEmpty) {
        final query = Transformer.urlEncodeMap(options.queryParameters);
        options
          ..headers['X-Enc-Query'] = HybridCipher.seal(
            aes,
            utf8.encode(query),
            HybridCipher.queryAad(method, path),
          )
          ..queryParameters = {};
      }
      options
        ..headers['X-Enc-Client'] = key.clientId
        ..headers['X-Enc-Key-Version'] = '${key.version}'
        ..headers['X-Enc-Key'] = HybridCipher.wrapKey(key.publicKey, aes)
        ..responseType = ResponseType.plain
        ..extra[_aesKey] = aes;
      handler.next(options);
    } on DioException catch (e) {
      handler.reject(e);
    } on Object catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    try {
      _open(response);
      handler.next(response);
    } on Object catch (e) {
      handler.reject(DioException(requestOptions: response.requestOptions, error: e));
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response == null) return handler.next(err);
    try {
      _open(response);
    } on Object {
      // Leave the error as it is; the caller still gets the status code.
    }
    final options = err.requestOptions;
    final stale = response.statusCode == 409 && _code(response.data) == 'key_version_stale';
    if (stale && options.extra[_retried] != true) {
      _keys.invalidate();
      if (options.extra[_original] case (
        final Object? data,
        final Map<String, dynamic> query,
        final String? type,
      )) {
        options
          ..data = data
          ..queryParameters = query
          ..contentType = type
          ..responseType = ResponseType.json
          ..extra[_retried] = true;
        for (final h in [
          'X-Enc-Content-Type',
          'X-Enc-Query',
          'X-Enc-Client',
          'X-Enc-Key-Version',
          'X-Enc-Key',
        ]) {
          options.headers.remove(h);
        }
        try {
          return handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    handler.next(err);
  }

  /// Replaces a sealed body with the decoded plaintext, in place.
  void _open(Response<dynamic> response) {
    final contentType = response.headers.value('x-enc-content-type');
    final aes = response.requestOptions.extra[_aesKey];
    if (contentType == null || aes is! Uint8List || response.data is! String) {
      if (response.data case final String text
          when response.requestOptions.extra[_aesKey] != null) {
        // A plain error from the middleware itself (e.g. key_version_stale).
        response.data = _tryJson(text);
      }
      return;
    }
    final options = response.requestOptions;
    final plain = utf8.decode(
      HybridCipher.open(
        aes,
        response.data as String,
        HybridCipher.responseAad(options.method, options.uri.path),
      ),
    );
    response.data = contentType.contains('json') ? _tryJson(plain) : plain;
  }

  static Object? _tryJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  static String? _code(Object? data) => switch (data) {
    {'detail': [{'code': final String code}, ...]} => code,
    _ => null,
  };
}
