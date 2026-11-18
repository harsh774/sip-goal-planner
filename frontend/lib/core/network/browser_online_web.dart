import 'dart:async';

import 'package:web/web.dart' as web;

/// The browser's own online flag and its `online`/`offline` events.
bool? browserOnline() => web.window.navigator.onLine;

Stream<bool>? browserOnlineChanges() {
  final controller = StreamController<bool>.broadcast();
  web.EventStreamProviders.onlineEvent.forTarget(web.window).listen((_) => controller.add(true));
  web.EventStreamProviders.offlineEvent.forTarget(web.window).listen((_) => controller.add(false));
  return controller.stream;
}
