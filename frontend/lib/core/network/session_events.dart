import 'dart:async';

/// Broadcasts "the server rejected our token" so the auth layer can log out.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void expire() => _expired.add(null);

  Future<void> dispose() => _expired.close();
}
