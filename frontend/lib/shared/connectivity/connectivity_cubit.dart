import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/connectivity_service.dart';

/// `true` while the device is online.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._service) : super(true) {
    _sub = _service.onlineChanges.listen(emit);
    unawaited(check());
  }

  final ConnectivityService _service;
  late final StreamSubscription<bool> _sub;

  Future<void> check() async {
    final online = await _service.isOnline();
    if (!isClosed) emit(online);
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
