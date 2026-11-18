import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _fromBuild = String.fromEnvironment('API_BASE_URL');

  /// Set with `--dart-define=API_BASE_URL=...`. Without it, the local dev API:
  /// the Android emulator reaches the host machine at 10.0.2.2.
  static String get apiBaseUrl {
    if (_fromBuild.isNotEmpty) return _fromBuild;
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return 'http://$host:8000/api/v1';
  }
}
