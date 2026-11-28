/// Lets long loops on the owning isolate yield to timers and frame work.
final class CooperativeWork {
  CooperativeWork() : _clock = Stopwatch()..start();

  final Stopwatch _clock;
  static const _budget = Duration(milliseconds: 8);

  Future<void>? checkpoint() =>
      _clock.elapsed < _budget ? null : yieldToEvents();

  Future<void> yieldToEvents() async {
    await Future<void>.delayed(Duration.zero);
    _clock.reset();
  }
}
