import 'package:connectivity_plus/connectivity_plus.dart';

import 'browser_online_stub.dart' if (dart.library.js_interop) 'browser_online_web.dart';

/// Whether the device has any network. It can't tell whether the API itself
/// is reachable; request errors cover that. Browsers use their own online
/// flag and events; other platforms use connectivity_plus.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onlineChanges =>
      (browserOnlineChanges() ?? _connectivity.onConnectivityChanged.map(_isOnline)).distinct();

  Future<bool> isOnline() async =>
      browserOnline() ?? _isOnline(await _connectivity.checkConnectivity());

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
