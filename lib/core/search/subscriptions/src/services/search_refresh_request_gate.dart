import 'dart:async';
import 'dart:collection';

class SearchRefreshRequestGate {
  SearchRefreshRequestGate({this.limit = 3})
    : assert(limit > 0, 'Concurrency limit must be positive');
  final int limit;
  final _waiting = Queue<Completer<void>>();
  var _active = 0;

  Future<T> run<T>(Future<T> Function() request) async {
    if (_active >= limit) {
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await waiter.future;
    } else {
      _active++;
    }
    try {
      return await request();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}
