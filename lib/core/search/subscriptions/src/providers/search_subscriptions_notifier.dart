// Dart imports:
import 'dart:async';

// Package imports:
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../../../../http/client/coordination.dart';
import '../../../../http/client/providers.dart';

// Project imports:
import '../../../../../foundation/data_mutation_coordinator.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../posts/post/providers.dart';
import '../data/providers.dart';
import '../refresh/chronological_search_scanner.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../services/search_refresh_service.dart';
import '../services/search_refresh_request_gate.dart';
import '../types/search_refresh.dart';
import '../types/search_following_feed.dart';
import '../types/search_organization.dart';
import '../types/search_subscription.dart';
import '../types/search_subscription_repository.dart';

final searchSubscriptionsProvider =
    AsyncNotifierProvider<
      SearchSubscriptionsNotifier,
      SearchSubscriptionsState
    >(SearchSubscriptionsNotifier.new);

class SearchSubscriptionsState extends Equatable {
  SearchSubscriptionsState({
    required List<SearchSubscription> subscriptions,
    required Set<String> refreshingIds,
    required this.batchCompleted,
    required this.batchTotal,
    this.batchProfileId,
    this.refreshingFeedId,
    Set<String> pendingRefreshIds = const {},
    this.feeds = const [],
    required this.organization,
  }) : subscriptions = List.unmodifiable(subscriptions),
       refreshingIds = Set.unmodifiable(refreshingIds),
       pendingRefreshIds = Set.unmodifiable(pendingRefreshIds);

  final List<SearchSubscription> subscriptions;
  final Set<String> refreshingIds;
  final Set<String> pendingRefreshIds;
  final int batchCompleted;
  final int batchTotal;
  final String? batchProfileId;
  final String? refreshingFeedId;
  final List<SearchFollowingFeed> feeds;
  final SearchOrganization organization;

  @override
  List<Object?> get props => [
    subscriptions,
    refreshingIds,
    pendingRefreshIds,
    batchCompleted,
    batchTotal,
    batchProfileId,
    refreshingFeedId,
    feeds,
    organization,
  ];
}

class SearchSubscriptionsNotifier
    extends AsyncNotifier<SearchSubscriptionsState> {
  SearchSubscriptionsNotifier({SearchRefreshService? refreshService})
    : _refreshService = refreshService;

  final SearchRefreshService? _refreshService;
  final Map<String, Future<SearchRefreshOutcome>> _inFlight = {};
  final Map<Object, Set<String>> _refreshPlans = {};
  final Map<String, int> _pausedProfileRefreshes = {};
  final _refreshTokens = <String, CancelToken>{};
  final _refreshOperations = <String, _SourceRefreshOperation>{};
  final _requestGate = SearchRefreshRequestGate();
  Future<void> _mutationTail = Future.value();
  Future<void> _batchTail = Future.value();
  Future<List<SearchRefreshOutcome>>? _feedRefreshFuture;
  String? _refreshingFeedId;
  CancelToken? _feedRefreshToken;
  var _batchCompleted = 0;
  var _batchTotal = 0;
  String? _batchProfileId;
  var _disposed = false;
  List<SearchFollowingFeed> _feeds = const [];
  var _organization = SearchOrganization(
    folders: const [],
    homeSearchIds: const [],
  );

  @override
  Future<SearchSubscriptionsState> build() async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _feedRefreshToken?.cancel();
      for (final token in _refreshTokens.values) {
        token.cancel();
      }
    });
    final repository = await _repository;
    _feeds = await repository.getFeeds();
    _organization = await repository.getOrganization();
    return _snapshot(await repository.getAll());
  }

  Future<SearchSubscriptionRepository> get _repository =>
      ref.read(searchSubscriptionRepositoryProvider.future);

  SearchRefreshService _service(SearchSubscriptionRepository repository) =>
      _refreshService ??
      SearchRefreshService(
        repository: repository,
        resolvePostRepository: (config) =>
            ref.read(originAwarePostRepoProvider(config)),
        resolvePostDataCodec: (config) => ref
            .read(booruEngineRegistryProvider)
            .getPostCapability(config.auth.booruType)
            ?.codec,
        resolveQueryAdapter: (config) =>
            ref
                .read(booruEngineRegistryProvider)
                .getRepository(config.booruType)
                ?.searchRefreshQueryAdapter(config) ??
            const UnsupportedSearchRefreshQueryAdapter(),
        scanner: ChronologicalSearchScanner(),
      );

  SearchRefreshProgress beginRefreshProgress([
    Iterable<String> ids = const [],
  ]) {
    final key = Object();
    void update(Iterable<String> ids) {
      if (_disposed) return;
      _refreshPlans[key] = ids.toSet();
      _publishActivity();
    }

    final progress = SearchRefreshProgress(update, () {
      _refreshPlans.remove(key);
      _publishActivity();
    });
    progress.update(ids);
    return progress;
  }

  Future<SearchRefreshProgress> planIndependentRefreshes(
    List<String> profiles,
  ) async {
    await future;
    final current = state.requireValue;
    final sourceIds = {for (final feed in current.feeds) ...feed.sourceIds};
    final profileIds = {
      for (final profile in profiles)
        profile: {
          for (final search in current.subscriptions)
            if (search.profileId == profile && !sourceIds.contains(search.id))
              search.id,
        },
    };
    final progress = beginRefreshProgress(
      profileIds.values.expand((ids) => ids),
    );
    progress._profileIds.addAll(profileIds);
    return progress;
  }

  Future<SearchFollowingFeed> saveFeed({
    required String profileId,
    required String name,
    required List<String> queries,
    String? id,
  }) => runSerializedMutation((repository) {
    _validateFeedQueries(profileId, queries);
    return repository.saveFeed(
      profileId: profileId,
      name: name,
      queries: queries,
      id: id,
    );
  });

  Future<int> bulkAddToFeed({
    required String feedId,
    required String rawQueries,
  }) => _mutate((repository) async {
    final feed = (await repository.getFeeds())
        .where((item) => item.id == feedId)
        .firstOrNull;
    if (feed == null) throw StateError('Feed not found');
    final searches = {
      for (final item in await repository.getAll()) item.id: item,
    };
    final existing = [
      for (final id in feed.sourceIds)
        if (searches[id] case final search?) search.query,
    ];
    final known = existing.map(normalizeSearchIdentity).toSet();
    final additions = [
      for (final query in parseBulkSearchQueries(rawQueries))
        if (known.add(normalizeSearchIdentity(query))) query,
    ];
    if (additions.isEmpty) return 0;
    _validateFeedQueries(feed.profileId, additions);
    await repository.saveFeed(
      profileId: feed.profileId,
      name: feed.name,
      queries: [...existing, ...additions],
      id: feed.id,
    );
    return additions.length;
  });

  Future<int> bulkPinToFolder({
    required String profileId,
    required String? folderId,
    required String rawQueries,
  }) => _mutate((repository) async {
    if (!ref.read(booruConfigProvider).any((c) => c.id == profileId)) {
      throw StateError('Profile not found');
    }
    final organization = await repository.getOrganization();
    if (folderId != null &&
        !organization.folders.any((folder) => folder.id == folderId)) {
      throw StateError('Folder not found');
    }
    final feedSourceIds = {
      for (final feed in await repository.getFeeds()) ...feed.sourceIds,
    };
    final known = {
      for (final search in await repository.getAll())
        if (search.profileId == profileId && !feedSourceIds.contains(search.id))
          normalizeSearchIdentity(search.query),
    };
    final additions = [
      for (final query in parseBulkSearchQueries(rawQueries))
        if (known.add(normalizeSearchIdentity(query))) query,
    ];
    if (additions.isEmpty) return 0;

    final created = <String>[];
    try {
      for (final query in additions) {
        created.add(
          (await repository.create(
            profileId: profileId,
            query: query,
            name: null,
          )).id,
        );
      }
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            for (final folder in organization.folders)
              if (folder.id == folderId)
                SharedSearchFolder(
                  id: folder.id,
                  name: folder.name,
                  searchIds: [...folder.searchIds, ...created],
                )
              else
                folder,
          ],
          homeSearchIds: [
            ...organization.homeSearchIds,
            if (folderId == null) ...created,
          ],
        ),
      );
    } catch (_) {
      for (final id in created) {
        await repository.delete(id);
      }
      rethrow;
    }
    return created.length;
  });

  void _validateFeedQueries(String profileId, List<String> queries) {
    final config = ref
        .read(booruConfigProvider)
        .where((c) => c.id == profileId)
        .firstOrNull;
    if (config == null) throw StateError('Missing feed profile');
    final adapter = ref
        .read(booruRepoProvider(config.auth))
        ?.searchRefreshQueryAdapter(config.auth);
    if (adapter == null ||
        !adapter.isSupported ||
        queries.any(
          (q) =>
              adapter.plan(q, after: null) is UnsupportedSearchRefreshQueryPlan,
        )) {
      throw const FormatException('Unsupported feed query');
    }
  }

  Future<SearchFollowingFeed?> setFeedFollowing({
    required String feedId,
    required String profileId,
    required String query,
    required bool following,
  }) => _mutate((repository) async {
    final feed = (await repository.getFeeds())
        .where((item) => item.id == feedId)
        .firstOrNull;
    if (feed == null || feed.profileId != profileId) {
      throw StateError('Feed profile mismatch');
    }
    final byId = {
      for (final search in await repository.getAll()) search.id: search,
    };
    final identity = normalizeSearchIdentity(query);
    if (identity.isEmpty) throw const FormatException('Empty feed query');
    final queries = [
      for (final id in feed.sourceIds)
        if (byId[id] case final search?) search.query,
    ];
    final updated = following
        ? {
            ...queries,
            if (!queries.any(
              (item) => normalizeSearchIdentity(item) == identity,
            ))
              query,
          }.toList()
        : queries
              .where((item) => normalizeSearchIdentity(item) != identity)
              .toList();
    if (updated.length == queries.length) return feed;
    if (updated.isEmpty) {
      await repository.deleteFeed(feed.id);
      return null;
    }
    if (following) _validateFeedQueries(profileId, [query]);
    return repository.saveFeed(
      profileId: profileId,
      name: feed.name,
      queries: updated,
      id: feed.id,
    );
  });

  Future<void> renameFeedMember({
    required String feedId,
    required SearchSubscription source,
    required String? name,
  }) => runSerializedMutation((repository) async {
    final feed = (await repository.getFeeds())
        .where((item) => item.id == feedId)
        .firstOrNull;
    final current = await repository.getById(source.id);
    final ownerExists = ref
        .read(booruConfigProvider)
        .any((config) => config.id == source.profileId);
    if (feed == null ||
        current == null ||
        !ownerExists ||
        !feed.sourceIds.contains(source.id) ||
        feed.profileId != current.profileId ||
        current.profileId != source.profileId ||
        current.query != source.query ||
        current.createdAt != source.createdAt ||
        current.runtimeRevision != source.runtimeRevision) {
      throw StateError('Feed member changed or is unavailable');
    }
    await repository.rename(source.id, name);
  });

  Future<List<SearchRefreshOutcome>> refreshFeed(String id) {
    if (_feedRefreshFuture case final running?) {
      return _refreshingFeedId == id ? running : Future.value(const []);
    }
    _refreshingFeedId = id;
    final result = _feedRefreshFuture = _refreshFeedBatch(id).whenComplete(() {
      _feedRefreshFuture = null;
      _refreshingFeedId = null;
      _publishActivity();
    });
    _publishActivity();
    return result;
  }

  Future<List<SearchRefreshOutcome>> _refreshFeedBatch(String id) async {
    await future;
    if (_disposed) return const [];
    final current = state.requireValue;
    final feed = current.feeds.firstWhereOrNull((feed) => feed.id == id);
    if (feed == null) return const [];
    final sourceIds = feed.sourceIds.toSet();
    // Attempts include failures, so persistent failures cannot monopolize each
    // batch. Successful checks cover older records without an attempt time.
    DateTime? activity(SearchSubscription source) =>
        switch ((source.lastAttemptAt, source.lastSuccessfulCheckAt)) {
          (final attempt?, final check?) =>
            attempt.isAfter(check) ? attempt : check,
          (final attempt, final check) => attempt ?? check,
        };
    final sources =
        current.subscriptions
            .where(
              (s) => sourceIds.contains(s.id) && s.profileId == feed.profileId,
            )
            .toList()
          ..sort((left, right) {
            final order = switch ((activity(left), activity(right))) {
              (null, null) => 0,
              (null, _) => -1,
              (_, null) => 1,
              (final a?, final b?) => a.compareTo(b),
            };
            return order == 0 ? left.id.compareTo(right.id) : order;
          });
    final planned = sources.take(10).toList();
    final token = _feedRefreshToken = CancelToken();
    final deadline = Timer(const Duration(seconds: 20), () => token.cancel());
    final progress = beginRefreshProgress(planned.map((s) => s.id));
    final pending = planned.map((s) => s.id).toSet();
    final outcomes = <SearchRefreshOutcome>[];
    try {
      for (final source in planned) {
        bool canContinue() =>
            !_disposed &&
            !token.isCancelled &&
            (state.valueOrNull?.feeds.any(
                  (f) =>
                      f.id == id &&
                      f.profileId == source.profileId &&
                      f.sourceIds.contains(source.id),
                ) ??
                false);
        if (!canContinue()) break;
        final outcome = await refresh(
          source.id,
          cancelToken: token,
          canStart: canContinue,
          canAdmit: canContinue,
        );
        outcomes.add(outcome);
        pending.remove(source.id);
        progress.update(pending);
        // Every source in a feed uses the same site; respect its cooldown rather
        // than submitting the rest of this batch to that site.
        if (outcome is SearchRefreshDeferred ||
            outcome is SearchRefreshFailed &&
                outcome.kind == SearchRefreshErrorKind.rateLimited) {
          break;
        }
      }
      return outcomes;
    } finally {
      deadline.cancel();
      progress.close();
      _feedRefreshToken = null;
    }
  }

  Future<void> moveFeed(String id, {required bool up}) => _mutate((
    repository,
  ) async {
    final all = await repository.getFeeds();
    final feed = all.firstWhereOrNull((feed) => feed.id == id);
    if (feed == null) return;
    final siblings = all.where((f) => f.profileId == feed.profileId).toList();
    final index = siblings.indexWhere((f) => f.id == id);
    final target = index + (up ? -1 : 1);
    if (target < 0 || target >= siblings.length) return;
    final moved = siblings.removeAt(index);
    siblings.insert(target, moved);
    await repository.setFeedOrder(feed.profileId, [
      for (final f in siblings) f.id,
    ]);
  });

  Future<void> deleteFeed(String id) =>
      runSerializedMutation((repository) => repository.deleteFeed(id));

  Future<void> markFeedRead(String id) =>
      runSerializedMutation((repository) async {
        final feed = (await repository.getFeeds())
            .where((feed) => feed.id == id)
            .firstOrNull;
        for (final sourceId in feed?.sourceIds ?? const <String>[]) {
          await repository.markRead(sourceId);
        }
      });

  Future<SharedSearchFolder> createSharedFolder(String name) =>
      _mutate((repository) async {
        final folder = SharedSearchFolder(
          id: const Uuid().v4(),
          name: name,
          searchIds: const [],
        );
        final organization = await repository.getOrganization();
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [...organization.folders, folder],
            homeSearchIds: organization.homeSearchIds,
          ),
        );
        return folder;
      });

  Future<SharedSearchFolder> createSharedFolderAndMovePin(
    String searchId,
    String name,
  ) => _mutate((repository) async {
    await _requireIndependentPin(repository, searchId);
    final folder = SharedSearchFolder(
      id: const Uuid().v4(),
      name: name,
      searchIds: [searchId],
    );
    final organization = _withoutSharedPin(
      await repository.getOrganization(),
      searchId,
    );
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [...organization.folders, folder],
        homeSearchIds: organization.homeSearchIds,
      ),
    );
    return folder;
  });

  Future<void> movePinToSharedFolder(String searchId, String? folderId) =>
      _mutate((repository) async {
        await _requireIndependentPin(repository, searchId);
        final current = await repository.getOrganization();
        final alreadyInDestination = folderId == null
            ? current.homeSearchIds.contains(searchId)
            : current.folders.any(
                (folder) =>
                    folder.id == folderId &&
                    folder.searchIds.contains(searchId),
              );
        if (alreadyInDestination) return;
        final organization = _withoutSharedPin(current, searchId);
        if (folderId != null &&
            !organization.folders.any((folder) => folder.id == folderId)) {
          throw StateError('Shared folder not found');
        }
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              for (final folder in organization.folders)
                if (folder.id == folderId)
                  SharedSearchFolder(
                    id: folder.id,
                    name: folder.name,
                    searchIds: [...folder.searchIds, searchId],
                  )
                else
                  folder,
            ],
            homeSearchIds: [
              ...organization.homeSearchIds,
              if (folderId == null) searchId,
            ],
          ),
        );
      });

  Future<void> reorderSharedPins(
    String? folderId,
    int oldIndex,
    int newIndex,
  ) => _mutate((repository) async {
    final organization = await repository.getOrganization();
    final ids = folderId == null
        ? organization.homeSearchIds.toList()
        : organization.folders
              .singleWhere((folder) => folder.id == folderId)
              .searchIds
              .toList();
    if (oldIndex < 0 ||
        oldIndex >= ids.length ||
        newIndex < 0 ||
        newIndex >= ids.length) {
      return;
    }
    final pin = ids.removeAt(oldIndex);
    ids.insert(newIndex, pin);
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [
          for (final folder in organization.folders)
            if (folder.id == folderId)
              SharedSearchFolder(
                id: folder.id,
                name: folder.name,
                searchIds: ids,
              )
            else
              folder,
        ],
        homeSearchIds: folderId == null ? ids : organization.homeSearchIds,
      ),
    );
  });

  Future<void> renameSharedFolder(String id, String name) =>
      _mutate((repository) async {
        final organization = await repository.getOrganization();
        organization.folders.singleWhere((folder) => folder.id == id);
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              for (final folder in organization.folders)
                if (folder.id == id)
                  SharedSearchFolder(
                    id: id,
                    name: name,
                    searchIds: folder.searchIds,
                  )
                else
                  folder,
            ],
            homeSearchIds: organization.homeSearchIds,
          ),
        );
      });

  Future<void> reorderSharedFolders(int oldIndex, int newIndex) =>
      _mutate((repository) async {
        final organization = await repository.getOrganization();
        final folders = organization.folders.toList();
        if (oldIndex < 0 ||
            oldIndex >= folders.length ||
            newIndex < 0 ||
            newIndex >= folders.length) {
          return;
        }
        final folder = folders.removeAt(oldIndex);
        folders.insert(newIndex, folder);
        await repository.replaceOrganization(
          SearchOrganization(
            folders: folders,
            homeSearchIds: organization.homeSearchIds,
          ),
        );
      });

  Future<void> deleteSharedFolderAndPins(String folderId) =>
      _mutate((repository) => repository.deleteSharedFolderAndPins(folderId));

  Future<List<SearchRefreshOutcome>> refreshSharedFolder(
    String folderId,
  ) async {
    await future;
    final current = state.requireValue;
    final ids = current.organization.folders
        .singleWhere((folder) => folder.id == folderId)
        .searchIds
        .toSet();
    final items =
        current.subscriptions
            .where((search) => ids.contains(search.id))
            .toList()
          ..sort(compareSearchRefreshPriority);
    final progress = beginRefreshProgress(items.map((item) => item.id));
    try {
      final outcomes = <SearchRefreshOutcome>[];
      for (final item in items) {
        try {
          outcomes.add(await refresh(item.id));
        } finally {
          progress.settle(item.id);
        }
      }
      return outcomes;
    } finally {
      progress.close();
    }
  }

  Future<({SearchSubscription subscription, SearchRefreshOutcome refresh})>
  pin({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    required String? name,
    String? folderId,
    String? newFolderName,
  }) async {
    final subscription = await _mutate((repository) async {
      if (newFolderName case final folderName?) {
        return repository.savePinInNewFolder(
          profileId: profileId,
          query: query,
          name: name,
          folderName: folderName,
        );
      }
      final existing = await repository.findByQuery(profileId, query);
      final subscription = switch (existing) {
        null => await repository.create(
          profileId: profileId,
          query: query,
          queryStructure: queryStructure,
          name: name,
        ),
        final saved when name != null => await repository.rename(
          saved.id,
          name,
        ),
        final saved => saved,
      };
      if (folderId != null) {
        final organization = _withoutSharedPin(
          await repository.getOrganization(),
          subscription.id,
        );
        if (!organization.folders.any((f) => f.id == folderId)) {
          throw StateError('Folder not found');
        }
        await repository.replaceOrganization(
          SearchOrganization(
            folders: [
              for (final folder in organization.folders)
                if (folder.id == folderId)
                  SharedSearchFolder(
                    id: folder.id,
                    name: folder.name,
                    searchIds: [...folder.searchIds, subscription.id],
                  )
                else
                  folder,
            ],
            homeSearchIds: organization.homeSearchIds,
          ),
        );
      }
      return subscription;
    });
    return (
      subscription: subscription,
      refresh: await refresh(subscription.id),
    );
  }

  Future<({SearchSubscription subscription, SearchRefreshOutcome? refresh})>
  edit(
    String id, {
    required String profileId,
    required String query,
    required String? name,
  }) async {
    final result = await _mutate((repository) async {
      if (!ref.read(booruConfigProvider).any((c) => c.id == profileId)) {
        throw MissingPinnedSearchProfileException();
      }
      await _requireIndependentPin(repository, id);
      final previous = (await repository.getById(id))!;
      final material =
          previous.profileId != profileId || previous.query != query.trim();
      final edited = await repository.edit(
        id,
        profileId: profileId,
        query: query,
        name: name,
      );
      return (subscription: edited, material: material);
    });
    if (!result.material) {
      return (subscription: result.subscription, refresh: null);
    }
    _refreshTokens.remove(id)?.cancel();
    _refreshOperations.remove(id);
    unawaited(_inFlight.remove(id));
    return (
      subscription: result.subscription,
      refresh: await refresh(id),
    );
  }

  Future<void> rename(String id, String? name) async {
    await _mutate((repository) => repository.rename(id, name));
  }

  Future<SearchSubscription> savePinInNewFolder({
    required String profileId,
    required String query,
    required String? name,
    required String folderName,
    String? existingPinId,
  }) => _mutate(
    (repository) => repository.savePinInNewFolder(
      profileId: profileId,
      query: query,
      name: name,
      folderName: folderName,
      existingPinId: existingPinId,
    ),
  );

  Future<void> reorder(String profileId, int oldIndex, int newIndex) async {
    await _mutate(
      (repository) => repository.reorder(profileId, oldIndex, newIndex),
    );
  }

  Future<void> markRead(String id) async {
    await _mutate((repository) => repository.markRead(id));
  }

  Future<void> delete(String id) =>
      _mutate((repository) => repository.delete(id));

  Future<SearchRefreshOutcome> refresh(
    String id, {
    bool Function()? canStart,
    bool Function()? canAdmit,
    Stream<void>? admissionChanges,
    void Function()? onStarted,
    ApiRequestClass requestClass = ApiRequestClass.userInitiated,
    CancelToken? cancelToken,
    bool waitForSettlement = false,
  }) {
    var operation = _refreshOperations[id];
    if (operation != null && operation.token.isCancelled) operation = null;
    if (operation?.dataQuota case final quota?
        when requestClass == ApiRequestClass.userInitiated ||
            requestClass == ApiRequestClass.interactive) {
      final retryAt = ref
          .read(apiRequestCoordinatorProvider)
          .snapshot(quota)
          .retryAt;
      if (retryAt != null) {
        if (!operation!.dataRunning) operation.disableCooldownReplay();
        return Future.value(SearchRefreshDeferred(retryAt));
      }
    }
    final owner = _SourceRefreshOwner(
      requestClass,
      canStart,
      onStarted,
      cancelToken,
      canAdmit,
      admissionChanges,
    );
    if (operation != null) {
      operation.add(owner);
      return waitForSettlement ? operation.result : operation.resultFor(owner);
    }
    final captured = state.valueOrNull?.subscriptions
        .where((s) => s.id == id)
        .firstOrNull;
    final shared = _SourceRefreshOperation(captured)..add(owner);
    _refreshOperations[id] = shared;
    _refreshTokens[id] = shared.token;
    late final Future<SearchRefreshOutcome> request;
    request =
        runWithApiRequestContext(
          ApiRequestContext(
            requestClassResolver: () => shared.priority,
            allowCooldownRetryResolver: () => !shared.manualJoined,
            changes: shared.changes.stream,
            onDataTransport: shared.trackDataTransport,
            cancelToken: shared.token,
            canStart: () => !_disposed && shared.live,
            canAdmit: () => shared.canAdmit,
            onStarted: shared.onStarted,
          ),
          () => _refresh(id, () => !_disposed && shared.live, shared),
        ).whenComplete(() {
          if (identical(_inFlight[id], request)) {
            _inFlight.remove(id);
            _refreshTokens.remove(id);
            _refreshOperations.remove(id);
          }
          unawaited(shared.changes.close());
          _publishActivity();
        });
    shared.result = request;
    _inFlight[id] = request;
    return waitForSettlement ? shared.result : shared.resultFor(owner);
  }

  Future<SearchRefreshOutcome> _refresh(
    String id,
    bool Function()? canStart,
    _SourceRefreshOperation operation,
  ) => _requestGate.run(() async {
    if (!(canStart?.call() ?? true)) return const SearchRefreshDiscarded();
    return _performRefresh(id, operation);
  });

  Future<SearchRefreshOutcome> _performRefresh(
    String id,
    _SourceRefreshOperation operation,
  ) async {
    await future;
    if (_disposed) return const SearchRefreshDiscarded();
    _publishActivity();
    final repository = await _repository;
    try {
      final subscription = await repository.getById(id);
      if (_disposed || subscription == null) {
        return const SearchRefreshDiscarded();
      }
      if (!operation.matches(subscription)) {
        return const SearchRefreshDiscarded();
      }
      if (_pausedProfileRefreshes.containsKey(subscription.profileId)) {
        return const SearchRefreshDiscarded();
      }
      final config = ref
          .read(booruConfigProvider)
          .firstWhereOrNull((config) => config.id == subscription.profileId);
      if (config == null) return const SearchRefreshDiscarded();
      final inherited = ApiRequestContext.current();
      return await runWithApiRequestContext(
        ApiRequestContext(
          requestClass: inherited.requestClass,
          requestClassResolver: inherited.requestClassResolver,
          allowCooldownRetryResolver: inherited.allowCooldownRetryResolver,
          changes: inherited.changes,
          onDataTransport: inherited.onDataTransport,
          cancelToken: inherited.cancelToken,
          canAdmit: inherited.canAdmit,
          allowCooldownRetry: inherited.allowCooldownRetry,
          onStarted: inherited.onStarted,
          canStart: () =>
              (inherited.canStart?.call() ?? true) &&
              !_pausedProfileRefreshes.containsKey(config.id) &&
              ref
                  .read(booruConfigProvider)
                  .any(
                    (latest) =>
                        latest.id == config.id && latest.auth == config.auth,
                  ) &&
              (state.valueOrNull?.subscriptions.any(
                    (latest) =>
                        latest.id == id &&
                        latest.createdAt == subscription.createdAt &&
                        latest.runtimeRevision == subscription.runtimeRevision,
                  ) ??
                  false),
        ),
        () => _service(
          repository,
        ).refresh(subscription, config, automatic: () => !operation.liveManual),
      );
    } catch (_) {
      return const SearchRefreshFailed(SearchRefreshErrorKind.other);
    } finally {
      if (!_disposed) await _serialize(() => _reload(repository));
    }
  }

  Future<List<SearchRefreshOutcome>> refreshAll(
    String profileId, {
    SearchRefreshProgress? progress,
  }) {
    final completer = Completer<List<SearchRefreshOutcome>>();
    _batchTail = _batchTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(
          await _refreshAll(profileId, onSettled: progress?.settle),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        // Fresh membership can omit a captured source, or reads can fail before workers.
        progress?.settleProfile(profileId);
      }
    });
    return completer.future;
  }

  Future<List<SearchRefreshOutcome>> _refreshAll(
    String profileId, {
    void Function(String)? onSettled,
  }) async {
    await future;
    final repository = await _repository;
    final feedSourceIds = {
      for (final feed in await repository.getFeeds()) ...feed.sourceIds,
    };
    final subscriptions =
        (await repository.getAll())
            .where(
              (item) =>
                  item.profileId == profileId &&
                  !feedSourceIds.contains(item.id),
            )
            .toList()
          ..sort(compareSearchRefreshPriority);
    final progress = beginRefreshProgress(subscriptions.map((item) => item.id));
    _batchCompleted = 0;
    _batchTotal = subscriptions.length;
    _batchProfileId = profileId;
    _publishActivity();
    final outcomes = List<SearchRefreshOutcome>.filled(
      subscriptions.length,
      const SearchRefreshDiscarded(),
    );
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < subscriptions.length && !_disposed) {
        final index = nextIndex++;
        try {
          outcomes[index] = await refresh(subscriptions[index].id);
        } catch (_) {
          outcomes[index] = const SearchRefreshFailed(
            SearchRefreshErrorKind.other,
          );
        }
        progress.settle(subscriptions[index].id);
        onSettled?.call(subscriptions[index].id);
        _batchCompleted++;
        _publishActivity();
      }
    }

    try {
      await Future.wait(List.generate(3, (_) => worker()));
      return outcomes;
    } finally {
      progress.close();
    }
  }

  Future<T> _mutate<T>(
    Future<T> Function(SearchSubscriptionRepository repository) operation,
  ) => runSerializedMutation(operation);

  Future<void> _requireIndependentPin(
    SearchSubscriptionRepository repository,
    String id,
  ) async {
    final search = await repository.getById(id);
    if (search == null ||
        (await repository.getFeeds()).any(
          (feed) => feed.sourceIds.contains(id),
        )) {
      throw StateError('Independent pinned search not found');
    }
  }

  SearchOrganization _withoutSharedPin(
    SearchOrganization organization,
    String searchId,
  ) => SearchOrganization(
    folders: [
      for (final folder in organization.folders)
        SharedSearchFolder(
          id: folder.id,
          name: folder.name,
          searchIds: folder.searchIds.where((id) => id != searchId),
        ),
    ],
    homeSearchIds: organization.homeSearchIds.where((id) => id != searchId),
  );

  Future<T> runSerializedMutation<T>(
    Future<T> Function(SearchSubscriptionRepository repository) operation,
  ) => _serialize(() async {
    await future;
    final repository = await _repository;
    try {
      return await operation(repository);
    } finally {
      await _reload(repository);
    }
  });

  Future<T> runWithProfileRefreshPaused<T>(
    String profileId,
    Future<T> Function() operation,
  ) async {
    final searches =
        state.valueOrNull?.subscriptions ?? const <SearchSubscription>[];
    for (final search in searches.where((s) => s.profileId == profileId)) {
      _refreshTokens[search.id]?.cancel();
    }
    _pausedProfileRefreshes.update(
      profileId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    try {
      return await operation();
    } finally {
      final remaining = _pausedProfileRefreshes[profileId]! - 1;
      if (remaining == 0) {
        _pausedProfileRefreshes.remove(profileId);
      } else {
        _pausedProfileRefreshes[profileId] = remaining;
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) => ref
      .read(dataMutationCoordinatorProvider)
      .runExclusive(() => _serializeLocally(operation));

  Future<T> _serializeLocally<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _reload(SearchSubscriptionRepository repository) async {
    final subscriptions = await repository.getAll();
    _feeds = await repository.getFeeds();
    _organization = await repository.getOrganization();
    if (!_disposed) state = AsyncData(_snapshot(subscriptions));
  }

  void _publishActivity() {
    if (_disposed) return;
    if (state.valueOrNull case final current?) {
      state = AsyncData(_snapshot(current.subscriptions));
    }
  }

  SearchSubscriptionsState _snapshot(List<SearchSubscription> subscriptions) =>
      SearchSubscriptionsState(
        subscriptions: subscriptions,
        feeds: List.unmodifiable(_feeds),
        organization: _organization,
        refreshingIds: _inFlight.keys.toSet(),
        pendingRefreshIds: {
          ..._inFlight.keys,
          for (final ids in _refreshPlans.values) ...ids,
        }.intersection(subscriptions.map((item) => item.id).toSet()),
        batchCompleted: _batchCompleted,
        batchTotal: _batchTotal,
        batchProfileId: _batchProfileId,
        refreshingFeedId: _refreshingFeedId,
      );
}

final class _SourceRefreshOwner {
  _SourceRefreshOwner(
    this.priority,
    this.canStart,
    this.onStarted,
    this.token,
    this.admissionGuard,
    this.admissionChanges,
  );
  final ApiRequestClass priority;
  final bool Function()? canStart;
  final void Function()? onStarted;
  final CancelToken? token;
  final bool Function()? admissionGuard;
  final Stream<void>? admissionChanges;
  bool get live => !(token?.isCancelled ?? false) && (canStart?.call() ?? true);
}

final class _SourceRefreshOperation {
  _SourceRefreshOperation(this.definition);
  final SearchSubscription? definition;
  bool matches(SearchSubscription value) =>
      definition == null ||
      definition!.createdAt == value.createdAt &&
          definition!.runtimeRevision == value.runtimeRevision;
  final owners = <_SourceRefreshOwner>{};
  final token = CancelToken();
  final changes = StreamController<void>.broadcast(sync: true);
  late final Future<SearchRefreshOutcome> result;
  var started = false;
  var manualJoined = false;
  ApiQuotaKey? dataQuota;
  var dataRunning = false;
  void trackDataTransport(Uri uri, bool running) {
    dataQuota = ApiQuotaKey.fromUri(uri);
    dataRunning = running;
  }

  void disableCooldownReplay() {
    manualJoined = true;
    notify();
  }

  bool get live => !token.isCancelled && owners.any((owner) => owner.live);
  bool get canAdmit =>
      live &&
      owners.any(
        (owner) => owner.live && (owner.admissionGuard?.call() ?? true),
      );
  bool get liveManual => owners.any(
    (owner) =>
        owner.live &&
        (owner.priority == ApiRequestClass.userInitiated ||
            owner.priority == ApiRequestClass.interactive),
  );
  ApiRequestClass get priority => owners
      .where((owner) => owner.live)
      .map((owner) => owner.priority)
      .fold(ApiRequestClass.preload, (a, b) => a.index < b.index ? a : b);
  void add(_SourceRefreshOwner owner) {
    owners.add(owner);
    owner.admissionChanges?.listen((_) => notify());
    manualJoined |=
        owner.priority == ApiRequestClass.userInitiated ||
        owner.priority == ApiRequestClass.interactive;
    if (started && owner.live) owner.onStarted?.call();
    owner.token?.whenCancel.then((_) {
      owners.remove(owner);
      if (!live) token.cancel();
      notify();
    });
    notify();
  }

  void notify() {
    if (!changes.isClosed) changes.add(null);
  }

  void onStarted() {
    if (started) return;
    started = true;
    for (final owner in owners.where((owner) => owner.live)) {
      owner.onStarted?.call();
    }
  }

  Future<SearchRefreshOutcome> resultFor(_SourceRefreshOwner owner) =>
      owner.token == null
      ? result
      : Future.any([
          result,
          owner.token!.whenCancel.then((_) => const SearchRefreshDiscarded()),
        ]);
}

List<String> parseBulkSearchQueries(String raw) {
  final seen = <String>{};
  return [
    for (final line in raw.split(RegExp(r'\r?\n')))
      if (normalizeSearchIdentity(line) case final identity
          when identity.isNotEmpty && seen.add(identity))
        line.trim(),
  ];
}

/// Transient ownership of a finite refresh pass, independent of physical requests.
final class SearchRefreshProgress {
  SearchRefreshProgress(this._publish, this._release);
  final void Function(Iterable<String>) _publish;
  final void Function() _release;
  Set<String> _ids = {};
  final _profileIds = <String, Set<String>>{};
  var _closed = false;
  void update(Iterable<String> ids) {
    if (_closed) return;
    _ids = ids.toSet();
    _publish(_ids);
  }

  void settle(String id) => update(_ids.difference({id}));
  void settleProfile(String profileId) =>
      update(_ids.difference(_profileIds.remove(profileId) ?? const {}));

  void close() {
    if (_closed) return;
    _closed = true;
    _release();
  }
}
