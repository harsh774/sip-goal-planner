import 'package:shared_preferences/shared_preferences.dart';

/// Persists the access token. On web this is localStorage; see the README for the trade-off.
class TokenStorage {
  TokenStorage(this._prefs);

  static const _key = 'access_token';

  final SharedPreferences _prefs;

  Future<String?> read() async => _prefs.getString(_key);

  Future<void> write(String token) => _prefs.setString(_key, token);

  Future<void> clear() => _prefs.remove(_key);
}
