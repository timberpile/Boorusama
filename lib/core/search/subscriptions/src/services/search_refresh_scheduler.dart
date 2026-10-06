import 'dart:math' as math;
import 'dart:async';
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
  DateTime get now => _clock.now().toUtc();
  final int maxChecks;
  final Duration runBudget;
  final Duration spacing;
  final _failures = <String, int>{};
  final _deferredUntil = <String, DateTime>{};
  final _stateIdentities = <String, ({DateTime createdAt, int revision})>{};
  DateTime? deferredUntil(String id) => _deferredUntil[id];
  var _running = false;

  void retainSources(Iterable<SearchSubscription> sources) {
    final identities = {
      for (final source in sources)
        source.id: (
          createdAt: source.createdAt,
          revision: source.runtimeRevision,
        ),
    };
    bool stale(String id) =>
        !identities.containsKey(id) || identities[id] != _stateIdentities[id];
    _failures.removeWhere((id, _) => stale(id));
    _deferredUntil.removeWhere((id, _) => stale(id));
    _stateIdentities.removeWhere((id, _) => stale(id));
  }

  bool isDue(SearchSubscription search, Duration interval) {
    final now = _clock.now().toUtc();
    if (_deferredUntil[search.id] case final retryAt?) {
      if (now.isBefore(retryAt)) return false;
      _deferredUntil.remove(search.id);
    }
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
    bool alreadyPlanned = false,
    required bool Function() canRun,
    required bool Function(SearchSubscription) canRefresh,
    required Future<SearchRefreshOutcome> Function(String) refresh,
    Future<void> Function(Duration)? wait,
    Future<void>? cancelled,
    void Function(Set<String>)? onPendingChanged,
  }) async {
    if (_running || !canRun()) return 0;
    _running = true;
    final startedAt = _clock.now();
    var checked = 0;
    try {
      // A run may contain only a selected batch; live-source cleanup belongs
      // to retainSources, using the authoritative subscription collection.
      final due = alreadyPlanned
          ? searches
          : (searches.where((s) => isDue(s, interval)).toList()
              ..sort(compareSearchRefreshPriority));
      final planned = due.where(canRefresh).take(maxChecks).toList();
      final pending = planned.map((search) => search.id).toSet();
      void publish() => onPendingChanged?.call(Set.unmodifiable(pending));
      publish();
      for (final search in planned) {
        if (!canRun() ||
            checked >= maxChecks ||
            _clock.now().difference(startedAt) >= runBudget) {
          break;
        }
        if (!canRefresh(search)) {
          pending.remove(search.id);
          publish();
          continue;
        }
        checked++;
        final identity = (
          createdAt: search.createdAt,
          revision: search.runtimeRevision,
        );
        try {
          final outcome = await refresh(search.id);
          _stateIdentities[search.id] = identity;
          switch (outcome) {
            case SearchRefreshFailed():
              _failures.update(search.id, (n) => n + 1, ifAbsent: () => 1);
            case SearchRefreshSucceeded():
              _failures.remove(search.id);
              _deferredUntil.remove(search.id);
            case SearchRefreshDeferred(:final retryAt):
              _deferredUntil[search.id] = retryAt;
            case SearchRefreshDiscarded():
              break;
          }
        } catch (_) {
          _stateIdentities[search.id] = identity;
          _failures.update(search.id, (n) => n + 1, ifAbsent: () => 1);
        }
        pending.remove(search.id);
        publish();
        if (spacing > Duration.zero && checked < maxChecks && canRun()) {
          await (wait?.call(spacing) ?? waitForSpacing(cancelled: cancelled));
        }
      }
      return checked;
    } finally {
      onPendingChanged?.call(const {});
      _running = false;
    }
  }

  Future<void> waitForSpacing({Future<void>? cancelled}) {
    final completed = Completer<void>();
    final timer = Timer(spacing, completed.complete);
    cancelled?.then((_) {
      timer.cancel();
      if (!completed.isCompleted) completed.complete();
    });
    return completed.future;
  }
}
