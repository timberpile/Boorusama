import 'dart:math' as math;
import 'package:clock/clock.dart';
import '../types/search_refresh.dart';
import '../types/search_subscription.dart';

class SearchRefreshScheduler {
  SearchRefreshScheduler({
    Clock clock = const Clock(),
    this.maxChecks = 10,
    this.runBudget = const Duration(seconds: 20),
    this.spacing = const Duration(seconds: 1),
  }) : _clock = clock;
  final Clock _clock;
  final int maxChecks;
  final Duration runBudget;
  final Duration spacing;
  final _failures = <String, int>{};
  var _running = false;

  bool isDue(SearchSubscription search, Duration interval) {
    final now = _clock.now().toUtc();
    if (search.lastSuccessfulCheckAt case final checked?) {
      if (now.difference(checked) <= interval) return false;
    }
    if (search.lastErrorKind != null && search.lastAttemptAt != null) {
      final failures = _failures[search.id] ?? 1;
      final minutes = math.min(30, 5 * (1 << math.min(3, failures - 1)));
      if (now.isBefore(search.lastAttemptAt!.add(Duration(minutes: minutes)))) {
        return false;
      }
    }
    return true;
  }

  Future<int> run({
    required List<SearchSubscription> searches,
    required Duration interval,
    required bool Function() canRun,
    required bool Function(SearchSubscription) canRefresh,
    required Future<SearchRefreshOutcome> Function(String) refresh,
    Future<void> Function(Duration) wait = Future<void>.delayed,
  }) async {
    if (_running || !canRun()) return 0;
    _running = true;
    final startedAt = _clock.now();
    var checked = 0;
    try {
      final ids = searches.map((s) => s.id).toSet();
      _failures.removeWhere((id, _) => !ids.contains(id));
      final due = searches.where((s) => isDue(s, interval)).toList()
        ..sort(compareSearchRefreshPriority);
      for (final search in due) {
        if (!canRun() ||
            checked >= maxChecks ||
            _clock.now().difference(startedAt) >= runBudget) {
          break;
        }
        if (!canRefresh(search)) continue;
        checked++;
        try {
          switch (await refresh(search.id)) {
            case SearchRefreshFailed():
              _failures.update(search.id, (n) => n + 1, ifAbsent: () => 1);
            case SearchRefreshSucceeded():
              _failures.remove(search.id);
            case SearchRefreshDiscarded():
              break;
          }
        } catch (_) {
          _failures.update(search.id, (n) => n + 1, ifAbsent: () => 1);
        }
        if (spacing > Duration.zero && checked < maxChecks && canRun()) {
          await wait(spacing);
        }
      }
      return checked;
    } finally {
      _running = false;
    }
  }
}
