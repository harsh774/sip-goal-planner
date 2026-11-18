import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether API payloads are sent encrypted. Remembered across launches; off by default.
class EncryptionSettings extends ValueNotifier<bool> {
  EncryptionSettings(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'encrypted_transport';

  Future<void> toggle() async {
    value = !value;
    await _prefs.setBool(_key, value);
  }
}
