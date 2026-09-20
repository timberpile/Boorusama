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
  var _foreground = false;
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
      if (allowed && _foreground) unawaited(run());
    });
    return false;
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _configure();
  }

  void _configure() {
    _timer?.cancel();
    _timer = null;
    if (!_disposed &&
        _foreground &&
        ref.read(settingsProvider).searchRefresh.enabled) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(run()),
      );
      unawaited(run());
    }
  }

  bool get _canRun =>
      !_disposed &&
      _foreground &&
      ref.read(settingsProvider).searchRefresh.enabled &&
      ref.read(automaticSearchRefreshNetworkAllowedProvider);

  Future<int> run() =>
      _runFuture ??= _run().whenComplete(() => _runFuture = null);

  Future<int> _run() async {
    if (!_canRun || state) return 0;
    state = true;
    try {
      final subscriptions = await ref.read(searchSubscriptionsProvider.future);
      if (!_canRun) return 0;
      final profiles = {
        for (final config in ref.read(booruConfigProvider)) config.id: config,
      };
      final interval = ref.read(settingsProvider).searchRefresh.interval;
      return await _scheduler.run(
        searches: subscriptions.subscriptions,
        interval: interval,
        canRun: () => _canRun,
        canRefresh: (search) {
          final current = ref.read(searchSubscriptionsProvider).valueOrNull;
          final latest = current?.subscriptions
              .where((s) => s.id == search.id)
              .firstOrNull;
          if (latest == null ||
              !_scheduler.isDue(latest, interval) ||
              (current?.refreshingIds.contains(search.id) ?? false)) {
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
        refresh: (id) => ref
            .read(searchSubscriptionsProvider.notifier)
            .refresh(id, canStart: () => _canRun),
      );
    } catch (_) {
      return 0;
    } finally {
      if (!_disposed) state = false;
    }
  }
}
