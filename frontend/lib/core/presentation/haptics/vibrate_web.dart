import 'dart:js_interop';

@JS('navigator.vibrate')
external JSAny? _vibrate(JSNumber ms);

@JS('navigator.vibrate')
external JSAny? get _vibrateFn;

/// No-op where the browser lacks the Vibration API (desktop, iOS Safari).
void vibrate(int milliseconds) {
  if (_vibrateFn == null) return;
  try {
    _vibrate(milliseconds.toJS);
  } catch (_) {}
}
