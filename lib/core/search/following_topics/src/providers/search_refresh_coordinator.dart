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
import '../types/following_topic.dart';
import '../types/search_refresh.dart';
import '../refresh/search_refresh_query_adapter.dart';
import 'following_topics_notifier.dart';

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
  final Map<Object, String?> _feedInitializationOwners = {};
  var _disposed = false;
  CancelToken? _runToken;
  CancelToken? _initializationToken;
  final _automaticOwners = <String, CancelToken>{};
  final _initialAttemptRevisions =
      <String, ({int revision, DateTime createdAt, DateTime attemptedAt})>{};

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
      if (!environment.allowed(ref.read(settingsProvider).searchRefresh)) {
        _runToken?.cancel();
        _initializationToken?.cancel();
      }
      _configure();
    });
    ref.listen(followingTopicsProvider, (previous, next) {
      _revokeDisabledAutomaticOwners();
      _publishStatus();
      Object definition(FollowingTopicsState? value) => [
        for (final source in value?.topics ?? [])
          [source.id, source.createdAt, source.runtimeRevision],
        for (final feed in value?.feeds ?? []) [feed.id, feed.sourceIds],
      ];
      if (_hasFeedInitializationInterest &&
          !_initializingRun &&
          _canInitialize) {
        unawaited(initializeFeeds());
      }
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

  FeedInitializationInterest acquireFeedInitializationInterest({
    String? feedId,
  }) {
    final owner = Object();
    _feedInitializationOwners[owner] = feedId;
    unawaited(initializeFeeds());
    return FeedInitializationInterest(() {
      if (_feedInitializationOwners.remove(owner) == null &&
          !_feedInitializationOwners.containsKey(owner)) {
        if (!_hasFeedInitializationInterest) {
          _initializationToken?.cancel();
          if (_initializingRun) _runToken?.cancel();
        }
      }
    });
  }

  bool get _hasFeedInitializationInterest =>
      _feedInitializationOwners.isNotEmpty;

  bool _feedHasInitializationInterest(String feedId) =>
      _feedInitializationOwners.values.any(
        (ownedFeedId) => ownedFeedId == null || ownedFeedId == feedId,
      );

  void _configure() {
    _revokeDisabledAutomaticOwners();
    _timer?.cancel();
    _timer = null;
    if (_initializingRun ? !_canInitialize : !_canRun) _runToken?.cancel();
    _publishStatus();
    unawaited(initializeFeeds());
    if (_canRun) {
      unawaited(run());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        _publishStatus();
        unawaited(run());
        if (_hasFeedInitializationInterest) unawaited(initializeFeeds());
      });
    }
  }

  bool _scopeAllowed(String id) {
    if (_disposed) return false;
    final current = ref.read(followingTopicsProvider).valueOrNull;
    if (!(current?.topics.any((source) => source.id == id) ?? false)) {
      return false;
    }
    final settings = ref.read(settingsProvider).searchRefresh;
    final folderIds = current!.organization.folders
        .map((folder) => folder.id)
        .toSet();
    final legacyFeedSource = current.feeds.any(
      (feed) => !folderIds.contains(feed.id) && feed.sourceIds.contains(id),
    );
    final topic = current.topics.where((source) => source.id == id).firstOrNull;
    if (topic?.autoUpdateEnabled != true) return false;
    return legacyFeedSource
        ? settings.topicFeedsEnabled
        : settings.followingTopicsEnabled;
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
      ref.read(automaticSearchRefreshNetworkAllowedProvider) &&
      ref
          .read(searchRefreshEnvironmentProvider)
          .allowed(ref.read(settingsProvider).searchRefresh);

  ConservativeRefreshPlan _plan(
    List<FollowingTopic> searches,
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
            followedTopic: !sourceIds.contains(search.id),
            feedSource: sourceIds.contains(search.id),
            supported: search.autoUpdateEnabled && _supported(search),
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

  bool _supported(FollowingTopic search) {
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
    final sources = ref.read(followingTopicsProvider).valueOrNull;
    if (sources != null) _scheduler.retainSources(sources.topics);
    final folderIds =
        sources?.organization.folders.map((folder) => folder.id).toSet() ??
        <String>{};
    final sourceIds = <String>{
      for (final feed in sources?.feeds ?? [])
        if (!folderIds.contains(feed.id)) ...feed.sourceIds,
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
              for (final source in sources?.topics ?? <FollowingTopic>[])
                source.id: ?_scheduler.deferredUntil(source.id),
            },
            eligible: sources == null
                ? 0
                : _plan(sources.topics, sourceIds).selectedIds.length,
          ),
        );
  }

  Future<void> initializeFeeds() {
    if (!_canInitialize || !_hasFeedInitializationInterest) {
      return Future.value();
    }
    return _initializationFuture ??= _initializeFeeds().whenComplete(
      () {
        _initializationFuture = null;
        if ((_initializationToken?.isCancelled ?? false) &&
            _canInitialize &&
            _hasFeedInitializationInterest) {
          scheduleMicrotask(() => unawaited(initializeFeeds()));
        }
      },
    );
  }

  Future<void> _initializeFeeds() async {
    final token = _initializationToken = CancelToken();
    final current = await ref.read(followingTopicsProvider.future);
    _initialAttemptRevisions.removeWhere(
      (id, identity) =>
          _scheduler.now.difference(identity.attemptedAt) >=
              const Duration(minutes: 5) ||
          !current.topics.any(
            (source) =>
                source.id == id &&
                source.runtimeRevision == identity.revision &&
                source.createdAt == identity.createdAt,
          ),
    );
    final attemptedIds = _initialAttemptRevisions.keys.toSet();
    while (!token.isCancelled &&
        _canInitialize &&
        _hasFeedInitializationInterest) {
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
    bool canRun() => initializing
        ? _canInitialize && _hasFeedInitializationInterest
        : _canRun;
    if (!canRun() || state) return 0;
    state = true;
    _initializingRun = initializing;
    _publishStatus();
    final admissionDeadline = _scheduler.now.add(_scheduler.runBudget);
    final token = _runToken = CancelToken();
    bool canContinue() => !token.isCancelled && canRun();
    var checked = 0;
    final progress = ref
        .read(followingTopicsProvider.notifier)
        .beginRefreshProgress();
    final progressDeadline = Timer(
      _scheduler.runBudget,
      () => progress.update(const []),
    );
    unawaited(token.whenCancel.then((_) => progress.update(const [])));
    try {
      final topics = await ref.read(followingTopicsProvider.future);
      if (!canContinue()) return 0;
      final profiles = {
        for (final config in ref.read(booruConfigProvider)) config.id: config,
      };
      final interval = ref.read(settingsProvider).searchRefresh.interval;
      final folders = {
        for (final folder in topics.organization.folders) folder.id: folder,
      };
      final sourceIds = <String>{
        for (final feed in topics.feeds)
          if (!folders.containsKey(feed.id)) ...feed.sourceIds,
      };
      final initializationIds = <String>{
        for (final feed in topics.feeds)
          if ((folders[feed.id]?.feedEnabled ?? true) &&
              (!initializing || _feedHasInitializationInterest(feed.id)))
            for (final id in feed.sourceIds)
              if (!feed.initializedSourceIds.contains(id)) id,
      };
      final plan = _plan(topics.topics, sourceIds);
      final automaticSources = [
        for (final id in plan.selectedIds)
          topics.topics.firstWhere((s) => s.id == id),
      ];
      final initialSources =
          topics.topics
              .where(
                (source) =>
                    initializationIds.contains(source.id) &&
                    !(_scheduler
                            .deferredUntil(source.id)
                            ?.isAfter(_scheduler.now) ??
                        false) &&
                    !(initialAttemptIds?.contains(source.id) ?? false),
              )
              .toList()
            ..sort(compareSearchRefreshPriority);
      return checked = await _scheduler.run(
        alreadyPlanned: true,
        onPendingChanged: (ids) => progress.update(
          canContinue() && _scheduler.now.isBefore(admissionDeadline)
              ? ids
              : const [],
        ),
        searches: initializing ? initialSources : automaticSources,
        interval: interval,
        cancelled: token.whenCancel.then<void>((_) {}),
        canRun: () =>
            canContinue() && _scheduler.now.isBefore(admissionDeadline),
        canRefresh: (search) {
          final current = ref.read(followingTopicsProvider).valueOrNull;
          final latest = current?.topics
              .where((s) => s.id == search.id)
              .firstOrNull;
          if (latest == null ||
              (initializing
                  ? initialAttemptIds.contains(search.id) ||
                        !(current?.feeds.any(
                              (feed) =>
                                  (current.organization.folders
                                          .where(
                                            (folder) => folder.id == feed.id,
                                          )
                                          .firstOrNull
                                          ?.feedEnabled ??
                                      true) &&
                                  feed.sourceIds.contains(search.id) &&
                                  !feed.initializedSourceIds.contains(
                                    search.id,
                                  ),
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
              .read(followingTopicsProvider.notifier)
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
                      .read(followingTopicsProvider)
                      .valueOrNull
                      ?.topics
                      .where((source) => source.id == id)
                      .firstOrNull;
                  if (latest != null) {
                    _initialAttemptRevisions[id] = (
                      revision: latest.runtimeRevision,
                      createdAt: latest.createdAt,
                      attemptedAt: _scheduler.now,
                    );
                  }
                },
                requestClass: ApiRequestClass.automatic,
                cancelToken: ownerToken,
                waitForSettlement: initializing,
              )
              .then((outcome) {
                if (initializing &&
                    (outcome is SearchRefreshSucceeded ||
                        outcome is SearchRefreshDiscarded)) {
                  _initialAttemptRevisions.remove(id);
                  initialAttemptIds.remove(id);
                }
                return outcome;
              })
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

final class FeedInitializationInterest {
  FeedInitializationInterest(this._onClose);

  final void Function() _onClose;
  var _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    _onClose();
  }
}
