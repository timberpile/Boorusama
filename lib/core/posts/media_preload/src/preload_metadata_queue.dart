import 'dart:async';

typedef PreloadMetadataRequest<K, V> = ({
  K key,
  Future<V?> Function() load,
});

/// A serial, latest-window queue. Loaded values and failed attempts are bounded
/// by the current window. In-flight shared futures are never cancelled because
/// the visible post may be awaiting the same cached request.
class PreloadMetadataQueue<K, V extends Object> {
  PreloadMetadataQueue({required this.onResolved});

  final void Function() onResolved;
  final _cache = <K, V>{};
  final _attempted = <K>{};
  Set<K> _wanted = {};
  List<PreloadMetadataRequest<K, V>> _pending = [];
  Future<void>? _draining;
  var _disposed = false;

  V? peek(K key) => _cache[key];

  Future<void> replace(List<PreloadMetadataRequest<K, V>> requests) {
    if (_disposed) return Future.value();
    _wanted = requests.map((request) => request.key).toSet();
    _cache.removeWhere((key, _) => !_wanted.contains(key));
    _attempted.removeWhere((key) => !_wanted.contains(key));
    _pending = List.of(requests);
    if (_draining case final running?) return running;
    final done = Completer<void>();
    _draining = done.future;
    unawaited(_drain(done));
    return done.future;
  }

  Future<void> _drain(Completer<void> done) async {
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final request = _pending.removeAt(0);
        if (_cache.containsKey(request.key) || !_attempted.add(request.key)) {
          continue;
        }
        V? value;
        try {
          value = await request.load();
        } catch (_) {
          // Speculative failures leave the visible loader's normal error path
          // intact. Do not spin on one unavailable post while it stays nearby.
        }
        if (_disposed || !_wanted.contains(request.key) || value == null) continue;
        _cache[request.key] = value;
        onResolved();
      }
    } catch (error, stackTrace) {
      done.completeError(error, stackTrace);
    } finally {
      // Release admission synchronously with the empty-queue check. A future
      // completion callback would leave a gap in which a new plan could stall.
      _draining = null;
      if (!done.isCompleted) done.complete();
    }
  }

  void cancel() {
    _wanted = {};
    _pending = [];
    _cache.clear();
    _attempted.clear();
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
