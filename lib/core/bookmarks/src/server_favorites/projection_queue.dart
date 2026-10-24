import 'dart:async';

/// Preserve acknowledgement order for each canonical post/target without
/// holding the global bookmark write lock while retrieving a missing snapshot.
/// A failed or obsolete projection cannot discard a valid neighboring action.
class ServerFavoriteProjectionQueue<K> {
  final _tails = <K, Future<void>>{};

  Future<void> run(K key, Future<void> Function() operation) {
    final completion = Completer<void>();
    final previous = _tails[key] ?? Future<void>.value();
    late final Future<void> tail;
    tail = previous.then((_) async {
      try {
        await operation();
        completion.complete();
      } catch (error, stackTrace) {
        completion.completeError(error, stackTrace);
      } finally {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }
    });
    // The internal tail absorbs operation failures. The returned completion
    // reports them to the caller, while a later acknowledgement still proceeds.
    _tails[key] = tail;
    return completion.future;
  }
}
