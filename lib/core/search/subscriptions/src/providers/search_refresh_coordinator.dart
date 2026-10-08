import 'dart:async';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../../../../http/client/coordination.dart';
import '../../../../http/client/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../settings/providers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../../foundation/networking/network_provider.dart';
import '../services/search_refresh_scheduler.dart';
import '../services/conservative_refresh_policy.dart';
import '../services/search_refresh_environment.dart';
import '../types/search_subscription.dart';
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

class SearchRefreshStatus {
  SearchRefreshStatus({
    this.lastRunAt,
    this.running = false,
    this.paused,
    this.eligible = 0,
    Map<String, DateTime> deferredUntilById = const {},
  }) : deferredUntilById = Map.unmodifiable(deferredUntilById);
  final DateTime? lastRunAt;
  final bool running;
  final RefreshSkipReason? paused;
  final int eligible;
  final Map<String, DateTime> deferredUntilById;
}

final searchRefreshStatusProvider =
    NotifierProvider<SearchRefreshStatusNotifier, SearchRefreshStatus>(
      SearchRefreshStatusNotifier.new,
    );

class SearchRefreshStatusNotifier extends Notifier<SearchRefreshStatus> {
  @override
  SearchRefreshStatus build() =>
      SearchRefreshStatus(paused: RefreshSkipReason.inactive);
  void update(SearchRefreshStatus value) => state = value;
}

class SearchRefreshCoordinator extends Notifier<bool> {
  SearchRefreshCoordinator({SearchRefreshScheduler? scheduler})
    : _scheduler = scheduler ?? SearchRefreshScheduler();
  final SearchRefreshScheduler _scheduler;
  var _initializingRun = false;
  DateTime? lastAutomaticRunAt;
  Timer? _timer;
  Future<int>? _runFuture;
  Future<void>? _initializationFuture;
  var _foreground = false;
  var _feedsOverviewActive = false;
  var _disposed = false;
  CancelToken? _runToken;
  CancelToken? _initializationToken;
  final _automaticOwners = <String, CancelToken>{};
  final _initialAttemptRevisions =
      <String, ({int revision, DateTime createdAt})>{};

  @override
  bool build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _runToken?.cancel();
      _initializationToken?.cancel();
      _timer?.cancel();
    });
    ref.listen(
      settingsProvider.select((s) => s.searchRefresh),
      (_, _) => _configure(),
    );
    ref.listen(automaticSearchRefreshNetworkAllowedProvider, (_, allowed) {
      if (!allowed) {
        _initializationToken?.cancel();
        if (_initializingRun) _runToken?.cancel();
      }
      if (allowed && _foreground) {
        unawaited(initializeFeeds());
      }
    });
    ref.listen(searchRefreshEnvironmentProvider, (_, environment) {
      if (!environment.allowed(ref.read(settingsProvider).searchRefresh) &&
          !_initializingRun) {
        _runToken?.cancel();
      }
      _configure();
    });
    ref.listen(searchSubscriptionsProvider, (previous, next) {
      _revokeDisabledAutomaticOwners();
      _publishStatus();
      Object definition(SearchSubscriptionsState? value) => [
        for (final source in value?.subscriptions ?? [])
          [source.id, source.createdAt, source.runtimeRevision],
        for (final feed in value?.feeds ?? []) [feed.id, feed.sourceIds],
      ];
      if (_canRun &&
          !const DeepCollectionEquality().equals(
            definition(previous?.valueOrNull),
            definition(next.valueOrNull),
          )) {
        unawaited(run());
      }
    });
    return false;
  }

  void setForeground(bool foreground, {bool deferPublication = false}) {
    if (_disposed) return;
    if (foreground && !_foreground) {
      ref.invalidate(nativeSearchRefreshEnvironmentProvider);
    }
    _foreground = foreground;
    if (!foreground) {
      _runToken?.cancel();
      _initializationToken?.cancel();
    }
    if (deferPublication) {
      _timer?.cancel();
      _timer = null;
      scheduleMicrotask(() {
        if (!_disposed) _publishStatus();
      });
    } else {
      _configure();
    }
  }

  void setFeedsOverviewActive(bool active) {
    _feedsOverviewActive = active;
    if (!active) {
      _initializationToken?.cancel();
      if (_initializingRun) _runToken?.cancel();
    }
    if (active) unawaited(initializeFeeds());
  }

  void _configure() {
    _revokeDisabledAutomaticOwners();
    _timer?.cancel();
    _timer = null;
    if (!_canRun && !_initializingRun) _runToken?.cancel();
    _publishStatus();
    unawaited(initializeFeeds());
    if (_canRun) {
      unawaited(run());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        _publishStatus();
        unawaited(run());
      });
    }
  }

  bool _scopeAllowed(String id) {
    if (_disposed) return false;
    final current = ref.read(searchSubscriptionsProvider).valueOrNull;
    if (!(current?.subscriptions.any((source) => source.id == id) ?? false)) {
      return false;
    }
    final settings = ref.read(settingsProvider).searchRefresh;
    final feedSource = current!.feeds.any(
      (feed) => feed.sourceIds.contains(id),
    );
    return feedSource
        ? settings.followingFeedsEnabled
        : settings.pinnedSearchesEnabled;
  }

  void _revokeDisabledAutomaticOwners() {
    if (_disposed) return;
    for (final entry in _automaticOwners.entries) {
      if (!_scopeAllowed(entry.key)) entry.value.cancel();
    }
    if (_automaticOwners.isNotEmpty) {
      ref.read(apiRequestCoordinatorProvider).refreshAdmissions();
    }
  }

  bool get _canRun =>
      !_disposed &&
      _foreground &&
      ref.read(settingsProvider).searchRefresh.enabled &&
      ref
          .read(searchRefreshEnvironmentProvider)
          .allowed(ref.read(settingsProvider).searchRefresh);

  bool get _canInitialize =>
      !_disposed &&
      _foreground &&
      ref.read(automaticSearchRefreshNetworkAllowedProvider);

  ConservativeRefreshPlan _plan(
    List<SearchSubscription> searches,
    Set<String> sourceIds,
  ) {
    final environment = ref.read(searchRefreshEnvironmentProvider);
    return planConservativeRefresh(
      now: _scheduler.now,
      settings: ref.read(settingsProvider).searchRefresh,
      foreground: _foreground,
      network: environment.powerKnown
          ? environment.network
          : RefreshNetwork.unknown,
      batterySaver: environment.batterySaver,
      sources: [
        for (final search in searches)
          RefreshSourceCandidate(
            id: search.id,
            pinned: !sourceIds.contains(search.id),
            feedSource: sourceIds.contains(search.id),
            supported: _supported(search),
            createdAt: search.createdAt,
            lastMaterialEditAt: search.lastMaterialEditAt,
            lastAttemptAt: search.lastAttemptAt,
            lastSuccessfulCheckAt: search.lastSuccessfulCheckAt,
            adaptiveState: search.adaptiveState,
            cooldownUntil: _scheduler.deferredUntil(search.id),
          ),
      ],
    );
  }

  bool _supported(SearchSubscription search) {
    final config = ref
        .read(booruConfigProvider)
        .where((c) => c.id == search.profileId)
        .firstOrNull;
    if (config == null) return false;
    final adapter = ref
        .read(booruRepoProvider(config.auth))
        ?.searchRefreshQueryAdapter(config.auth);
    return supportsSearchRefreshQuery(adapter, search.query);
  }

  void _publishStatus() {
    if (_disposed) return;
    final settings = ref.read(settingsProvider).searchRefresh;
    final environment = ref.read(searchRefreshEnvironmentProvider);
    final sources = ref.read(searchSubscriptionsProvider).valueOrNull;
    if (sources != null) _scheduler.retainSources(sources.subscriptions);
    final sourceIds = <String>{
      for (final feed in sources?.feeds ?? []) ...feed.sourceIds,
    };
    final reason = !settings.enabled
        ? RefreshSkipReason.disabled
        : !_foreground
        ? RefreshSkipReason.inactive
        : !environment.powerKnown ||
              environment.network == RefreshNetwork.unknown
        ? RefreshSkipReason.unsupported
        : environment.batterySaver
        ? RefreshSkipReason.batterySaver
        : !environment.allowed(settings)
        ? RefreshSkipReason.network
        : null;
    ref
        .read(searchRefreshStatusProvider.notifier)
        .update(
          SearchRefreshStatus(
            lastRunAt: lastAutomaticRunAt,
            running: state && !_initializingRun,
            paused: reason,
            deferredUntilById: {
              for (final source
                  in sources?.subscriptions ?? <SearchSubscription>[])
                source.id: ?_scheduler.deferredUntil(source.id),
            },
            eligible: sources == null
                ? 0
                : _plan(sources.subscriptions, sourceIds).selectedIds.length,
          ),
        );
  }

  Future<void> initializeFeeds() {
    if (!_canInitialize || !_feedsOverviewActive) return Future.value();
    return _initializationFuture ??= _initializeFeeds().whenComplete(
      () {
        _initializationFuture = null;
        if ((_initializationToken?.isCancelled ?? false) &&
            _canInitialize &&
            _feedsOverviewActive) {
          scheduleMicrotask(() => unawaited(initializeFeeds()));
        }
      },
    );
  }

  Future<void> _initializeFeeds() async {
    final token = _initializationToken = CancelToken();
    final current = await ref.read(searchSubscriptionsProvider.future);
    _initialAttemptRevisions.removeWhere(
      (id, identity) => !current.subscriptions.any(
        (source) =>
            source.id == id &&
            source.runtimeRevision == identity.revision &&
            source.createdAt == identity.createdAt,
      ),
    );
    final attemptedIds = _initialAttemptRevisions.keys.toSet();
    while (!token.isCancelled && _canInitialize && _feedsOverviewActive) {
      final checked = await _startRun(initialAttemptIds: attemptedIds);
      if (checked == 0) break;
      if (_scheduler.spacing > Duration.zero) {
        await _scheduler.waitForSpacing(
          cancelled: token.whenCancel.then<void>((_) {}),
        );
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
    _initializingRun = initializing;
    _publishStatus();
    final admissionDeadline = _scheduler.now.add(_scheduler.runBudget);
    final token = _runToken = CancelToken();
    bool canContinue() => !token.isCancelled && canRun();
    var checked = 0;
    final progress = ref
        .read(searchSubscriptionsProvider.notifier)
        .beginRefreshProgress();
    final progressDeadline = Timer(
      _scheduler.runBudget,
      () => progress.update(const []),
    );
    unawaited(token.whenCancel.then((_) => progress.update(const [])));
    try {
      final subscriptions = await ref.read(searchSubscriptionsProvider.future);
      if (!canContinue()) return 0;
      final profiles = {
        for (final config in ref.read(booruConfigProvider)) config.id: config,
      };
      final interval = ref.read(settingsProvider).searchRefresh.interval;
      final sourceIds = {
        for (final feed in subscriptions.feeds)
          if (profiles.containsKey(feed.profileId)) ...feed.sourceIds,
      };
      final plan = _plan(subscriptions.subscriptions, sourceIds);
      final automaticSources = [
        for (final id in plan.selectedIds)
          subscriptions.subscriptions.firstWhere((s) => s.id == id),
      ];
      return checked = await _scheduler.run(
        alreadyPlanned: !initializing,
        onPendingChanged: (ids) => progress.update(
          canContinue() && _scheduler.now.isBefore(admissionDeadline)
              ? ids
              : const [],
        ),
        searches:
            (initializing ? subscriptions.subscriptions : automaticSources)
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
        cancelled: token.whenCancel.then<void>((_) {}),
        canRun: () =>
            canContinue() && _scheduler.now.isBefore(admissionDeadline),
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
                  : !_plan([
                          latest,
                        ], sourceIds).selectedIds.contains(latest.id) ||
                        (current?.refreshingIds.contains(search.id) ??
                            false))) {
            return false;
          }
          final config = profiles[latest.profileId];
          if (config == null) return false;
          final adapter = ref
              .read(booruRepoProvider(config.auth))
              ?.searchRefreshQueryAdapter(config.auth);
          return supportsSearchRefreshQuery(adapter, latest.query);
        },
        refresh: (id) {
          var physicallyStarted = false;
          final ownerToken = CancelToken();
          if (!initializing) _automaticOwners[id] = ownerToken;
          bool ownerScopeAllowed() => initializing || _scopeAllowed(id);
          final admissionChanges = StreamController<void>.broadcast(sync: true);
          unawaited(token.whenCancel.then((_) => ownerToken.cancel()));
          final remaining = admissionDeadline.difference(_scheduler.now);
          final deadlineTimer = Timer(
            remaining.isNegative ? Duration.zero : remaining,
            () {
              if (!physicallyStarted) {
                ownerToken.cancel();
              } else if (!admissionChanges.isClosed) {
                admissionChanges.add(null);
              }
            },
          );
          return ref
              .read(searchSubscriptionsProvider.notifier)
              .refresh(
                id,
                canStart: () =>
                    canContinue() &&
                    ownerScopeAllowed() &&
                    (physicallyStarted ||
                        _scheduler.now.isBefore(admissionDeadline)),
                canAdmit: () =>
                    canContinue() &&
                    ownerScopeAllowed() &&
                    _scheduler.now.isBefore(admissionDeadline),
                admissionChanges: admissionChanges.stream,
                onStarted: () {
                  physicallyStarted = true;
                  if (initialAttemptIds == null) return;
                  initialAttemptIds.add(id);
                  final latest = ref
                      .read(searchSubscriptionsProvider)
                      .valueOrNull
                      ?.subscriptions
                      .where((source) => source.id == id)
                      .firstOrNull;
                  if (latest != null) {
                    _initialAttemptRevisions[id] = (
                      revision: latest.runtimeRevision,
                      createdAt: latest.createdAt,
                    );
                  }
                },
                requestClass: ApiRequestClass.automatic,
                cancelToken: ownerToken,
                waitForSettlement: initializing,
              )
              .whenComplete(() {
                if (identical(_automaticOwners[id], ownerToken)) {
                  _automaticOwners.remove(id);
                }
                deadlineTimer.cancel();
                unawaited(admissionChanges.close());
              });
        },
      );
    } catch (_) {
      return 0;
    } finally {
      progressDeadline.cancel();
      progress.close();
      if (identical(_runToken, token)) _runToken = null;
      if (!_disposed) {
        if (!initializing && checked > 0) lastAutomaticRunAt = _scheduler.now;
        state = false;
        _publishStatus();
      }
    }
  }
}
