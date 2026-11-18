import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/endpoints.dart';

class TransportKey {
  const TransportKey({required this.clientId, required this.version, required this.publicKey});

  final String clientId;
  final int version;

  /// Base64 SubjectPublicKeyInfo DER.
  final String publicKey;
}

/// Fetches and caches the server's public key for this client. Uses its own
/// plain Dio so fetching the key is never itself encrypted.
class TransportKeySource {
  TransportKeySource(String baseUrl, {Future<String> Function()? appVersion})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ),
      _appVersion = appVersion ?? _pubspecVersion;

  final Dio _dio;
  final Future<String> Function() _appVersion;
  Future<TransportKey>? _pending;

  /// The client id is the app version from pubspec.yaml (e.g. "1.0.0"), so each
  /// release has its own keys and an old release can be cut off by revoking them.
  static Future<String> _pubspecVersion() async => (await PackageInfo.fromPlatform()).version;

  /// One fetch shared by concurrent requests; a failed fetch is retried next time.
  Future<TransportKey> current() => _pending ??= _fetch().catchError((Object e) {
    _pending = null;
    throw e;
  });

  /// After the server reports the cached version as stale.
  void invalidate() => _pending = null;

  Future<TransportKey> _fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.publicKey,
      queryParameters: {'client_id': await _appVersion()},
    );
    if (response.data case {
      'client_id': final String id,
      'key_version': final int version,
      'public_key': final String key,
    }) {
      return TransportKey(clientId: id, version: version, publicKey: key);
    }
    throw const FormatException('Unexpected public key response');
  }
}
