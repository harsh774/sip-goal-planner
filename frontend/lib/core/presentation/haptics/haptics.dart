import 'package:flutter/services.dart';

import 'vibrate_stub.dart' if (dart.library.js_interop) 'vibrate_web.dart';

/// A short tick for value steps (sliders). Native platforms use the system
/// haptic; mobile browsers that support it use the Vibration API.
abstract final class Haptics {
  static void tick() {
    HapticFeedback.selectionClick();
    vibrate(8);
  }
}
