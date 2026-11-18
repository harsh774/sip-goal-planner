import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

/// Waits until events stop arriving for [quiet], then handles only the latest;
/// a newer event cancels a handler still running.
EventTransformer<E> debounceRestartable<E>(Duration quiet) =>
    (events, mapper) => restartable<E>()(_debounce(events, quiet), mapper);

Stream<E> _debounce<E>(Stream<E> source, Duration quiet) {
  Timer? timer;
  StreamSubscription<E>? sub;
  late final StreamController<E> out;
  out = StreamController<E>(
    onListen: () {
      sub = source.listen(
        (event) {
          timer?.cancel();
          timer = Timer(quiet, () => out.add(event));
        },
        onError: out.addError,
        onDone: () {
          timer?.cancel();
          out.close();
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      return sub?.cancel();
    },
  );
  return out.stream;
}
