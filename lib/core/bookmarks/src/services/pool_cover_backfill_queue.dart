/// One background metadata lookup at a time; rebuilding a card reuses its job.
final class PoolCoverBackfillQueue {
  final _jobs = <Object, Future<void>>{};
  Future<void> _tail = Future.value();

  Future<void> run(Object key, Future<void> Function() operation) =>
      _jobs.putIfAbsent(key, () {
        final result = _tail.then((_) => operation());
        _tail = result.catchError((Object _) {});
        return result;
      });
}
