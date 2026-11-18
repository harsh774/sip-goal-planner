import 'dart:async';

/// Awaits [work]; if it is still pending after [after], calls [onSlow] once.
/// Blocs use it to switch a loading state to "slow connection".
Future<T> withSlowNotice<T>(
  Future<T> work,
  void Function() onSlow, {
  Duration after = const Duration(seconds: 3),
}) async {
  final timer = Timer(after, onSlow);
  try {
    return await work;
  } finally {
    timer.cancel();
  }
}
