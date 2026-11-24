import 'package:clock/clock.dart';

/// Serial in-flight deduplication with bounded, short-lived result retention.
final class PoolCoverBackfillQueue {
  PoolCoverBackfillQueue({
    this.cooldown = const Duration(minutes: 1),
    this.maxCompletedJobs = 256,
  }) {
    if (cooldown.isNegative || maxCompletedJobs < 1) {
      throw ArgumentError('Invalid cover retention');
    }
  }
  final Duration cooldown;
  final int maxCompletedJobs;
  final _jobs = <Object, Future<dynamic>>{};
  final _completed = <Object, ({DateTime until, Future<dynamic> result})>{};
  Future<void> _tail = Future.value();

  Future<T> run<T>(Object key, Future<T> Function() operation) {
    final now = clock.now();
    _completed.removeWhere((_, entry) => !now.isBefore(entry.until));
    if (_jobs[key] case final pending?) return pending as Future<T>;
    if (_completed[key] case final retained?) {
      return retained.result as Future<T>;
    }
    final result = _tail.then<T>((_) => operation());
    _jobs[key] = result;
    void complete() {
      _jobs.remove(key);
      _completed[key] = (until: clock.now().add(cooldown), result: result);
      while (_completed.length > maxCompletedJobs) {
        _completed.remove(_completed.keys.first);
      }
    }

    // Both outcomes are handled, including when a disposed card drops its waiter.
    _tail = result.then<void>(
      (_) => complete(),
      onError: (Object _, StackTrace _) => complete(),
    );
    return result;
  }
}
