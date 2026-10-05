import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../settings/providers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../../foundation/networking/network_provider.dart';
import '../services/search_refresh_scheduler.dart';
import '../refresh/search_refresh_query_adapter.dart';
import 'search_subscriptions_notifier.dart';

final automaticSearchRefreshNetworkAllowedProvider = Provider<bool>((ref) {
  final connection = ref.watch(currentConnectivityProvider).valueOrNull;
  return connection != null &&
      !connection.contains(ConnectivityResult.none) &&
      (connection.contains(ConnectivityResult.wifi) ||
          connection.contains(ConnectivityResult.ethernet));
});

final searchRefreshCoordinatorProvider =
    NotifierProvider<SearchRefreshCoordinator, bool>(
      SearchRefreshCoordinator.new,
    );

class SearchRefreshCoordinator extends Notifier<bool> {
  SearchRefreshCoordinator({SearchRefreshScheduler? scheduler})
    : _scheduler = scheduler ?? SearchRefreshScheduler();
  final SearchRefreshScheduler _scheduler;
  Timer? _timer;
  Future<int>? _runFuture;
  Future<void>? _initializationFuture;
  var _foreground = false;
  var _feedsOverviewActive = false;
  var _disposed = false;

  @override
  bool build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    ref.listen(
      settingsProvider.select((s) => s.searchRefresh),
      (_, _) => _configure(),
    );
    ref.listen(automaticSearchRefreshNetworkAllowedProvider, (_, allowed) {
      if (allowed && _foreground) {
        unawaited(initializeFeeds());
      }
    });
    return false;
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _configure();
  }

  void setFeedsOverviewActive(bool active) {
    _feedsOverviewActive = active;
    if (active) unawaited(initializeFeeds());
  }

  void _configure() {
    _timer?.cancel();
    _timer = null;
    unawaited(initializeFeeds());
  }

  bool get _canRun =>
      _canInitialize && ref.read(settingsProvider).searchRefresh.enabled;

  bool get _canInitialize =>
      !_disposed &&
      _foreground &&
      ref.read(automaticSearchRefreshNetworkAllowedProvider);

  Future<void> initializeFeeds() {
    if (!_canInitialize || !_feedsOverviewActive) return Future.value();
    return _initializationFuture ??= _initializeFeeds().whenComplete(
      () => _initializationFuture = null,
    );
  }

  Future<void> _initializeFeeds() async {
    final attemptedIds = <String>{};
    while (_canInitialize && _feedsOverviewActive) {
      final checked = await _startRun(initialAttemptIds: attemptedIds);
      if (checked == 0) break;
      if (_scheduler.spacing > Duration.zero) {
        await Future<void>.delayed(_scheduler.spacing);
      }
    }
  }

  Future<int> run() => _canRun ? _startRun() : Future.value(0);

  Future<int> _startRun({Set<String>? initialAttemptIds}) =>
      _runFuture ??= _run(
        initialAttemptIds: initialAttemptIds,
      ).whenComplete(() => _runFuture = null);

  Future<int> _run({Set<String>? initialAttemptIds}) async {
    final initializing = initialAttemptIds != null;
    bool canRun() =>
        initializing ? _canInitialize && _feedsOverviewActive : _canRun;
    if (!canRun() || state) return 0;
    state = true;
    try {
      final subscriptions = await ref.read(searchSubscriptionsProvider.future);
      if (!canRun()) return 0;
      final profiles = {
        for (final config in ref.read(booruConfigProvider)) config.id: config,
      };
      final interval = ref.read(settingsProvider).searchRefresh.interval;
      final sourceIds = {
        for (final feed in subscriptions.feeds)
          if (profiles.containsKey(feed.profileId)) ...feed.sourceIds,
      };
      return await _scheduler.run(
        searches: subscriptions.subscriptions
            .where(
              (search) =>
                  !initializing ||
                  sourceIds.contains(search.id) &&
                      search.lastSuccessfulCheckAt == null &&
                      search.lastAttemptAt == null &&
                      !initialAttemptIds.contains(search.id),
            )
            .toList(),
        interval: interval,
        canRun: canRun,
        canRefresh: (search) {
          final current = ref.read(searchSubscriptionsProvider).valueOrNull;
          final latest = current?.subscriptions
              .where((s) => s.id == search.id)
              .firstOrNull;
          if (latest == null ||
              (initializing
                  ? latest.lastSuccessfulCheckAt != null ||
                        latest.lastAttemptAt != null ||
                        initialAttemptIds.contains(search.id) ||
                        !(current?.feeds.any(
                              (feed) => feed.sourceIds.contains(search.id),
                            ) ??
                            false)
                  : !_scheduler.isDue(latest, interval) ||
                        (current?.refreshingIds.contains(search.id) ??
                            false))) {
            return false;
          }
          final config = profiles[latest.profileId];
          if (config == null) return false;
          final adapter = ref
              .read(booruRepoProvider(config.auth))
              ?.searchRefreshQueryAdapter(config.auth);
          return adapter != null &&
              adapter.isSupported &&
              adapter.plan(latest.query, after: null)
                  is SupportedSearchRefreshQueryPlan;
        },
        refresh: (id) {
          return ref
              .read(searchSubscriptionsProvider.notifier)
              .refresh(
                id,
                canStart: () {
                  final allowed = canRun();
                  if (allowed) initialAttemptIds?.add(id);
                  return allowed;
                },
              );
        },
      );
    } catch (_) {
      return 0;
    } finally {
      if (!_disposed) state = false;
    }
  }
}
