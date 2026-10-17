import '../../../../groups/folder_tree.dart';
import '../../../../settings/providers.dart';
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
import '../types/topic_feed.dart';
import '../types/topic_organization.dart';
import '../types/following_topic.dart';
import '../types/following_topic_repository.dart';

final followingTopicsProvider =
    AsyncNotifierProvider<FollowingTopicsNotifier, FollowingTopicsState>(
      FollowingTopicsNotifier.new,
    );

class FollowingTopicsState extends Equatable {
  FollowingTopicsState({
    required List<FollowingTopic> topics,
    required Set<String> refreshingIds,
    required this.batchCompleted,
    required this.batchTotal,
    this.batchProfileId,
    this.refreshingFeedId,
    this.feedRefreshChecked = 0,
    this.feedRefreshTotal = 0,
    Set<String> pendingRefreshIds = const {},
    this.feeds = const [],
    required this.organization,
  }) : topics = List.unmodifiable(topics),
       refreshingIds = Set.unmodifiable(refreshingIds),
       pendingRefreshIds = Set.unmodifiable(pendingRefreshIds);

  final List<FollowingTopic> topics;
  final Set<String> refreshingIds;
  final Set<String> pendingRefreshIds;
  final int batchCompleted;
  final int batchTotal;
  final String? batchProfileId;
  final String? refreshingFeedId;
  final int feedRefreshChecked;
  final int feedRefreshTotal;
  final List<TopicFeed> feeds;
  final TopicOrganization organization;

  @override
  List<Object?> get props => [
    topics,
    refreshingIds,
    pendingRefreshIds,
    batchCompleted,
    batchTotal,
    batchProfileId,
    refreshingFeedId,
    feedRefreshChecked,
    feedRefreshTotal,
    feeds,
    organization,
  ];
}

class FollowingTopicsNotifier extends AsyncNotifier<FollowingTopicsState> {
  FollowingTopicsNotifier({SearchRefreshService? refreshService})
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
  var _feedRefreshChecked = 0;
  var _feedRefreshTotal = 0;
  CancelToken? _feedRefreshToken;
  var _batchCompleted = 0;
  var _batchTotal = 0;
  String? _batchProfileId;
  var _disposed = false;
  List<TopicFeed> _feeds = const [];
  var _organization = TopicOrganization(folders: const []);

  @override
  Future<FollowingTopicsState> build() async {
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

  Future<FollowingTopicRepository> get _repository =>
      ref.read(followingTopicRepositoryProvider.future);

  SearchRefreshService _service(FollowingTopicRepository repository) =>
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
    final folderIds = current.organization.folders
        .map((folder) => folder.id)
        .toSet();
    final legacyFeedSourceIds = {
      for (final feed in current.feeds)
        if (!folderIds.contains(feed.id)) ...feed.sourceIds,
    };
    final profileIds = {
      for (final profile in profiles)
        profile: {
          for (final search in current.topics)
            if (search.profileId == profile &&
                !legacyFeedSourceIds.contains(search.id))
              search.id,
        },
    };
    final progress = beginRefreshProgress(
      profileIds.values.expand((ids) => ids),
    );
    progress._profileIds.addAll(profileIds);
    return progress;
  }

  Future<TopicFeed> saveFeed({
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

  Future<int> bulkFollowToFolder({
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
    final destinationIds = organization.directIds(folderId).toSet();
    final known = {
      for (final search in await repository.getAll())
        if (search.profileId == profileId && destinationIds.contains(search.id))
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
        TopicOrganization(
          folders: [
            for (final folder in organization.folders)
              if (folder.id == folderId)
                TopicFolder(
                  id: folder.id,
                  name: folder.name,
                  feedEnabled: folder.feedEnabled,
                  feedMaxPosts: folder.feedMaxPosts,
                  parentId: folder.parentId,
                  position: folder.position,
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

  Future<TopicFeed?> setFeedFollowing({
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
    required FollowingTopic source,
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
      _feedRefreshChecked = 0;
      _feedRefreshTotal = 0;
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
    final folder = current.organization.folders
        .where((folder) => folder.id == id)
        .firstOrNull;
    if (folder != null && !folder.feedEnabled) return const [];
    final folderFeed = folder != null;
    final hosts = {
      for (final config in ref.read(booruConfigProvider))
        config.id: Uri.tryParse(config.url)?.host ?? config.url,
    };
    final blockedHosts = <String>{};
    // Attempts include failures, so persistent failures cannot monopolize each
    // batch. Successful checks cover older records without an attempt time.
    DateTime? activity(FollowingTopic source) =>
        switch ((source.lastAttemptAt, source.lastSuccessfulCheckAt)) {
          (final attempt?, final check?) =>
            attempt.isAfter(check) ? attempt : check,
          (final attempt, final check) => attempt ?? check,
        };
    final sources =
        current.topics
            .where(
              (s) =>
                  sourceIds.contains(s.id) &&
                  (folderFeed || s.profileId == feed.profileId),
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
    _feedRefreshChecked = 0;
    _feedRefreshTotal = planned.length;
    _publishActivity();
    final token = _feedRefreshToken = CancelToken();
    final deadline = Timer(const Duration(seconds: 20), () => token.cancel());
    final progress = beginRefreshProgress(planned.map((s) => s.id));
    final pending = planned.map((s) => s.id).toSet();
    final outcomes = <SearchRefreshOutcome>[];
    try {
      for (final source in planned) {
        final host = hosts[source.profileId] ?? source.profileId;
        if (blockedHosts.contains(host)) {
          pending.remove(source.id);
          progress.update(pending);
          _feedRefreshChecked++;
          _publishActivity();
          continue;
        }
        bool canContinue() =>
            !_disposed &&
            !token.isCancelled &&
            (state.valueOrNull?.feeds.any(
                  (f) =>
                      f.id == id &&
                      (folderFeed || f.profileId == source.profileId) &&
                      (!folderFeed ||
                          (state.valueOrNull?.organization.folders.any(
                                (folder) =>
                                    folder.id == id && folder.feedEnabled,
                              ) ??
                              false)) &&
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
        _feedRefreshChecked++;
        _publishActivity();
        // Pause only the affected site in a mixed-profile folder feed.
        if (outcome is SearchRefreshDeferred ||
            outcome is SearchRefreshFailed &&
                outcome.kind == SearchRefreshErrorKind.rateLimited) {
          blockedHosts.add(host);
          if (!folderFeed) break;
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

  Future<void> initializeUnifiedFollowing() async {
    final settings = ref.read(settingsProvider).searchRefresh;
    final migrated = await runSerializedMutation(
      (repository) => repository.migrateLegacyTopicFeeds(
        topicsAutoUpdateEnabled: settings.followingTopicsEnabled,
        feedsAutoUpdateEnabled: settings.topicFeedsEnabled,
      ),
    );
    if (migrated && !settings.followingTopicsEnabled) {
      // Scope switches become per-topic preferences. All Topics now use one
      // scope switch, while the global automatic-refresh choice stays intact.
      final saved = await ref
          .read(settingsNotifierProvider.notifier)
          .updateWith(
            (current) => current.copyWith(
              searchRefresh: current.searchRefresh.copyWith(
                followingTopicsEnabled: true,
              ),
            ),
          );
      if (!saved) {
        throw StateError('Could not save unified topic refresh settings');
      }
    }
  }

  Future<TopicFeed?> openFolderFeed(String folderId) => runSerializedMutation(
    (repository) => repository.ensureFolderFeed(
      folderId,
      fallbackProfileId: ref.read(booruConfigProvider).firstOrNull?.id,
    ),
  );

  Future<void> clearFolderFeedCache(String folderId) => runSerializedMutation(
    (repository) => repository.clearFolderFeedCache(folderId),
  );

  Future<void> clearAllFeedCaches() =>
      runSerializedMutation((repository) => repository.clearAllFeedCaches());

  Future<TopicFolder> createSharedFolder(
    String name, {
    String? parentId,
    bool feedEnabled = false,
    int feedMaxPosts = topicFeedRetention,
  }) => _mutate((repository) async {
    final folder = TopicFolder(
      id: const Uuid().v4(),
      name: name,
      parentId: parentId,
      feedEnabled: feedEnabled,
      feedMaxPosts: feedMaxPosts,
      position: (await repository.getOrganization()).tree
          .children(parentId)
          .length,
    );
    final organization = await repository.getOrganization();
    FolderTree([...organization.folders, folder]);
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [...organization.folders, folder],
        homeSearchIds: organization.homeSearchIds,
      ),
    );
    return folder;
  });

  Future<void> setSharedFolderFeedOptions(
    String folderId, {
    required bool enabled,
    int? maxPosts,
  }) => _mutate((repository) async {
    if (maxPosts != null && maxPosts < 1) {
      throw ArgumentError.value(maxPosts, 'maxPosts', 'Must be positive');
    }
    final organization = await repository.getOrganization();
    if (!organization.folders.any((folder) => folder.id == folderId)) {
      throw StateError('Folder not found');
    }
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          for (final folder in organization.folders)
            folder.id == folderId
                ? folder.copyWith(
                    feedEnabled: enabled,
                    feedMaxPosts: maxPosts,
                  )
                : folder,
        ],
        placements: organization.placements,
      ),
    );
  });

  Future<TopicFolder> createSharedFolderAndMoveTopic(
    String searchId,
    String name, {
    String? parentId,
    bool feedEnabled = false,
    int feedMaxPosts = topicFeedRetention,
  }) => _mutate((repository) async {
    await _requireIndependentTopic(repository, searchId);
    final folder = TopicFolder(
      id: const Uuid().v4(),
      name: name,
      parentId: parentId,
      feedEnabled: feedEnabled,
      feedMaxPosts: feedMaxPosts,
      position: (await repository.getOrganization()).tree
          .children(parentId)
          .length,
      searchIds: [searchId],
    );
    final organization = _withoutSharedTopic(
      await repository.getOrganization(),
      searchId,
    );
    FolderTree([...organization.folders, folder]);
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [...organization.folders, folder],
        homeSearchIds: organization.homeSearchIds,
      ),
    );
    return folder;
  });

  Future<void> moveTopicToSharedFolder(String searchId, String? folderId) =>
      moveFolderItems(searchIds: {searchId}, destination: folderId);

  Future<void> moveFolderItems({
    Set<String> folderIds = const {},
    Set<String> searchIds = const {},
    required String? destination,
  }) => _mutate((repository) async {
    for (final id in searchIds) {
      await _requireIndependentTopic(repository, id);
    }
    final current = await repository.getOrganization();
    await repository.replaceOrganization(
      current.move(
        folderIds: folderIds,
        searchIds: searchIds,
        destination: destination,
      ),
    );
  });

  Future<void> reorderSharedTopics(
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
    final topic = ids.removeAt(oldIndex);
    ids.insert(newIndex, topic);
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          for (final folder in organization.folders)
            if (folder.id == folderId)
              TopicFolder(
                id: folder.id,
                name: folder.name,
                feedEnabled: folder.feedEnabled,
                feedMaxPosts: folder.feedMaxPosts,
                parentId: folder.parentId,
                position: folder.position,
                searchIds: ids,
              )
            else
              folder,
        ],
        homeSearchIds: folderId == null ? ids : organization.homeSearchIds,
      ),
    );
  });

  Future<void> renameSharedFolder(
    String id,
    String name, {
    required String? parentId,
    bool? feedEnabled,
    int? maxPosts,
  }) => _mutate((repository) async {
    final organization = await repository.getOrganization();
    organization.folders.singleWhere((folder) => folder.id == id);
    final moved = organization.move(folderIds: {id}, destination: parentId);
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          for (final folder in moved.folders)
            if (folder.id == id)
              TopicFolder(
                id: id,
                name: name,
                feedEnabled: feedEnabled ?? folder.feedEnabled,
                feedMaxPosts: maxPosts ?? folder.feedMaxPosts,
                parentId: folder.parentId,
                position: folder.position,
                searchIds: folder.searchIds,
              )
            else
              folder,
        ],
        placements: moved.placements,
      ),
    );
  });

  Future<void> reorderSharedFolders(
    int oldIndex,
    int newIndex, {
    String? parentId,
  }) => _mutate((repository) async {
    final organization = await repository.getOrganization();
    final siblings = organization.tree.children(parentId);
    final folders = [
      for (final f in siblings)
        organization.folders.singleWhere((item) => item.id == f.id),
    ];
    if (oldIndex < 0 ||
        oldIndex >= folders.length ||
        newIndex < 0 ||
        newIndex >= folders.length) {
      return;
    }
    final folder = folders.removeAt(oldIndex);
    folders.insert(newIndex, folder);
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          for (final f in organization.folders)
            if (f.parentId != parentId) f,
          for (final (position, f) in folders.indexed)
            TopicFolder(
              id: f.id,
              name: f.name,
              feedEnabled: f.feedEnabled,
              feedMaxPosts: f.feedMaxPosts,
              parentId: f.parentId,
              position: position,
              searchIds: f.searchIds,
            ),
        ],
        homeSearchIds: organization.homeSearchIds,
      ),
    );
  });

  Future<void> deleteSharedFolderAndTopics(
    String folderId, {
    TopicOrganization? expectedOrganization,
  }) => _mutate((repository) async {
    final current = await repository.getOrganization();
    if (expectedOrganization != null && expectedOrganization != current) {
      throw SearchFolderChangedException(current);
    }
    await repository.deleteSharedFolderAndTopics(folderId);
  });

  Future<List<SearchRefreshOutcome>> refreshSharedFolder(
    String folderId,
  ) async {
    await future;
    final current = state.requireValue;
    final ids = current.organization.recursiveIds(folderId).toSet();
    final items =
        current.topics.where((search) => ids.contains(search.id)).toList()
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

  Future<({FollowingTopic topic, SearchRefreshOutcome refresh})> follow({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    required String? name,
    String? folderId,
    String? newFolderName,
  }) async {
    final topic = await followLocally(
      profileId: profileId,
      query: query,
      queryStructure: queryStructure,
      name: name,
      folderId: folderId,
      newFolderName: newFolderName,
    );
    return (
      topic: topic,
      refresh: await refresh(topic.id),
    );
  }

  Future<FollowingTopic> followLocally({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    required String? name,
    String? folderId,
    String? newFolderName,
    String? newFolderParentId,
    bool newFolderFeedEnabled = false,
    int newFolderMaxPosts = topicFeedRetention,
  }) => _mutate((repository) async {
    if (newFolderName case final folderName?) {
      return repository.saveTopicInNewFolder(
        profileId: profileId,
        query: query,
        queryStructure: queryStructure,
        name: name,
        folderName: folderName,
        parentFolderId: newFolderParentId,
        feedEnabled: newFolderFeedEnabled,
        feedMaxPosts: newFolderMaxPosts,
      );
    }
    final organization = await repository.getOrganization();
    final destinationIds = organization.directIds(folderId).toSet();
    final identity = normalizeSearchIdentity(query);
    final existing = (await repository.getAll())
        .where(
          (search) =>
              destinationIds.contains(search.id) &&
              search.profileId == profileId &&
              normalizeSearchIdentity(search.query) == identity,
        )
        .firstOrNull;
    final topic = switch (existing) {
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
      final organization = _withoutSharedTopic(
        await repository.getOrganization(),
        topic.id,
      );
      if (!organization.folders.any((f) => f.id == folderId)) {
        throw StateError('Folder not found');
      }
      await repository.replaceOrganization(
        TopicOrganization(
          folders: [
            for (final folder in organization.folders)
              if (folder.id == folderId)
                TopicFolder(
                  id: folder.id,
                  name: folder.name,
                  feedEnabled: folder.feedEnabled,
                  feedMaxPosts: folder.feedMaxPosts,
                  parentId: folder.parentId,
                  position: folder.position,
                  searchIds: [...folder.searchIds, topic.id],
                )
              else
                folder,
          ],
          homeSearchIds: organization.homeSearchIds,
        ),
      );
    }
    return topic;
  });

  Future<
    ({
      List<FollowingTopic> added,
      List<FollowingTopic> removed,
    })
  >
  setFollowDestinations({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    String? name,
    required Set<String?> folderIds,
  }) => _mutate((repository) async {
    final identity = normalizeSearchIdentity(query);
    if (identity.isEmpty) {
      throw const FormatException('Followed topic queries cannot be empty.');
    }
    var organization = await repository.getOrganization();
    final topics = {
      for (final topic in await repository.getAll()) topic.id: topic,
    };
    final existingByFolder = <String?, FollowingTopic>{};
    for (final placement in organization.placements) {
      final topic = topics[placement.itemId];
      if (topic != null &&
          topic.profileId == profileId &&
          normalizeSearchIdentity(topic.query) == identity) {
        existingByFolder[placement.folderId] = topic;
      }
    }
    final knownFolderIds = organization.folders
        .map((folder) => folder.id)
        .toSet();
    if (folderIds.whereType<String>().any(
      (id) => !knownFolderIds.contains(id),
    )) {
      throw StateError('Folder not found');
    }

    final removed = <FollowingTopic>[];
    for (final entry in existingByFolder.entries) {
      if (!folderIds.contains(entry.key)) {
        removed.add(entry.value);
        await repository.delete(entry.value.id);
      }
    }

    final template = existingByFolder.values.firstOrNull;
    final added = <FollowingTopic>[];
    final addedByFolder = <String, List<String>>{};
    for (final folderId in folderIds) {
      if (existingByFolder.containsKey(folderId)) continue;
      final topic = await repository.create(
        profileId: profileId,
        query: query,
        queryStructure: queryStructure ?? template?.queryStructure,
        name: name ?? template?.name,
      );
      if (template != null && !template.autoUpdateEnabled) {
        await repository.setAutoUpdate([topic.id], false);
      }
      if (folderId != null) {
        addedByFolder.putIfAbsent(folderId, () => []).add(topic.id);
      }
      added.add(topic);
    }
    if (addedByFolder.isNotEmpty) {
      organization = await repository.getOrganization();
      final filedIds = addedByFolder.values.expand((ids) => ids).toSet();
      await repository.replaceOrganization(
        TopicOrganization(
          folders: [
            for (final folder in organization.folders)
              TopicFolder(
                id: folder.id,
                name: folder.name,
                parentId: folder.parentId,
                position: folder.position,
                searchIds: [
                  ...folder.searchIds.where((id) => !filedIds.contains(id)),
                  ...?addedByFolder[folder.id],
                ],
                feedEnabled: folder.feedEnabled,
                feedMaxPosts: folder.feedMaxPosts,
              ),
          ],
          homeSearchIds: organization.homeSearchIds.where(
            (id) => !filedIds.contains(id),
          ),
        ),
      );
    }
    return (added: added, removed: removed);
  });

  Future<({FollowingTopic topic, SearchRefreshOutcome? refresh})> edit(
    String id, {
    required String profileId,
    required String query,
    required String? name,
    bool? autoUpdateEnabled,
  }) async {
    final result = await editLocally(
      id,
      profileId: profileId,
      query: query,
      name: name,
      autoUpdateEnabled: autoUpdateEnabled,
    );
    if (!result.material) {
      return (topic: result.topic, refresh: null);
    }
    return (
      topic: result.topic,
      refresh: await refresh(id),
    );
  }

  Future<({FollowingTopic topic, bool material})> editLocally(
    String id, {
    required String profileId,
    required String query,
    required String? name,
    bool? autoUpdateEnabled,
  }) async {
    final result = await _mutate((repository) async {
      if (!ref.read(booruConfigProvider).any((c) => c.id == profileId)) {
        throw MissingFollowingTopicProfileException();
      }
      await _requireIndependentTopic(repository, id);
      final previous = (await repository.getById(id))!;
      final material =
          previous.profileId != profileId || previous.query != query.trim();
      final edited = await repository.edit(
        id,
        profileId: profileId,
        query: query,
        name: name,
      );
      if (autoUpdateEnabled != null &&
          autoUpdateEnabled != previous.autoUpdateEnabled) {
        await repository.setAutoUpdate([id], autoUpdateEnabled);
      }
      return (topic: edited, material: material);
    });
    if (!result.material) {
      return result;
    }
    _refreshTokens.remove(id)?.cancel();
    _refreshOperations.remove(id);
    unawaited(_inFlight.remove(id));
    return result;
  }

  Future<void> rename(String id, String? name) async {
    await _mutate((repository) => repository.rename(id, name));
  }

  Future<FollowingTopic> saveTopicInNewFolder({
    required String profileId,
    required String query,
    required String? name,
    required String folderName,
    SearchQueryStructure? queryStructure,
    String? parentFolderId,
    bool feedEnabled = false,
    int feedMaxPosts = topicFeedRetention,
    String? existingTopicId,
  }) => _mutate(
    (repository) => repository.saveTopicInNewFolder(
      profileId: profileId,
      query: query,
      queryStructure: queryStructure,
      name: name,
      folderName: folderName,
      parentFolderId: parentFolderId,
      feedEnabled: feedEnabled,
      feedMaxPosts: feedMaxPosts,
      existingTopicId: existingTopicId,
    ),
  );

  Future<void> reorder(String profileId, int oldIndex, int newIndex) async {
    await _mutate(
      (repository) => repository.reorder(profileId, oldIndex, newIndex),
    );
  }

  Future<void> setAutoUpdate(Iterable<String> ids, bool enabled) =>
      _mutate((repository) => repository.setAutoUpdate(ids, enabled));

  Future<void> markRead(String id) async {
    await _mutate((repository) => repository.markRead(id));
  }

  Future<void> markTopicsRead(Iterable<String> ids) =>
      _mutate((repository) async {
        for (final id in ids.toSet()) {
          await repository.markRead(id);
        }
      });

  Future<void> deleteTopics(Iterable<String> ids) =>
      _mutate((repository) async {
        for (final id in ids.toSet()) {
          await repository.delete(id);
        }
      });

  Future<void> removeSelection({
    required Iterable<String> folderIds,
    required Iterable<String> topicIds,
    TopicOrganization? expectedOrganization,
  }) => _mutate((repository) async {
    final organization = await repository.getOrganization();
    if (expectedOrganization != null && expectedOrganization != organization) {
      throw SearchFolderChangedException(organization);
    }
    final tree = organization.tree;
    final selectedFolders = folderIds.where(tree.byId.containsKey).toSet();
    final rootFolders = selectedFolders
        .where(
          (id) => !tree
              .ancestors(tree.byId[id]!.parentId)
              .any((folder) => selectedFolders.contains(folder.id)),
        )
        .toSet();
    final topicsInFolders = {
      for (final folderId in rootFolders)
        ...organization.recursiveIds(folderId),
    };
    for (final folderId in rootFolders) {
      await repository.deleteSharedFolderAndTopics(folderId);
    }
    for (final topicId in topicIds.toSet().difference(topicsInFolders)) {
      await repository.delete(topicId);
    }
  });

  Future<List<SearchRefreshOutcome>> refreshTopics(Iterable<String> ids) async {
    final outcomes = <SearchRefreshOutcome>[];
    for (final id in ids.toSet()) {
      outcomes.add(await refresh(id));
    }
    return outcomes;
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
    final captured = state.valueOrNull?.topics
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
      final topic = await repository.getById(id);
      if (_disposed || topic == null) {
        return const SearchRefreshDiscarded();
      }
      if (!operation.matches(topic)) {
        return const SearchRefreshDiscarded();
      }
      if (_pausedProfileRefreshes.containsKey(topic.profileId)) {
        return const SearchRefreshDiscarded();
      }
      final config = ref
          .read(booruConfigProvider)
          .firstWhereOrNull((config) => config.id == topic.profileId);
      if (config == null) return const SearchRefreshDiscarded();
      final folderStates = {
        for (final folder
            in state.valueOrNull?.organization.folders ?? <TopicFolder>[])
          folder.id: folder,
      };
      final initializingFeeds =
          state.valueOrNull?.feeds
              .where(
                (feed) =>
                    (folderStates[feed.id]?.feedEnabled ?? true) &&
                    feed.sourceIds.contains(id) &&
                    !feed.initializedSourceIds.contains(id),
              )
              .toList() ??
          <TopicFeed>[];
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
              (state.valueOrNull?.topics.any(
                    (latest) =>
                        latest.id == id &&
                        latest.createdAt == topic.createdAt &&
                        latest.runtimeRevision == topic.runtimeRevision,
                  ) ??
                  false),
        ),
        () => _service(repository).refresh(
          topic,
          config,
          automatic: () => !operation.liveManual,
          // A new feed needs a complete initial snapshot even if this topic
          // already has a tracking checkpoint from its earlier life as a topic.
          snapshotPostLimit: initializingFeeds.fold<int>(
            1,
            (limit, feed) => feed.maxPosts > limit ? feed.maxPosts : limit,
          ),
          requireFullSnapshot: initializingFeeds.isNotEmpty,
        ),
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
    final folderIds = (await repository.getOrganization()).folders
        .map((folder) => folder.id)
        .toSet();
    final legacyFeedSourceIds = {
      for (final feed in await repository.getFeedMetadata())
        if (!folderIds.contains(feed.id)) ...feed.sourceIds,
    };
    final topics =
        (await repository.getAll())
            .where(
              (item) =>
                  item.profileId == profileId &&
                  !legacyFeedSourceIds.contains(item.id),
            )
            .toList()
          ..sort(compareSearchRefreshPriority);
    final progress = beginRefreshProgress(topics.map((item) => item.id));
    _batchCompleted = 0;
    _batchTotal = topics.length;
    _batchProfileId = profileId;
    _publishActivity();
    final outcomes = List<SearchRefreshOutcome>.filled(
      topics.length,
      const SearchRefreshDiscarded(),
    );
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < topics.length && !_disposed) {
        final index = nextIndex++;
        try {
          outcomes[index] = await refresh(topics[index].id);
        } catch (_) {
          outcomes[index] = const SearchRefreshFailed(
            SearchRefreshErrorKind.other,
          );
        }
        progress.settle(topics[index].id);
        onSettled?.call(topics[index].id);
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
    Future<T> Function(FollowingTopicRepository repository) operation,
  ) => runSerializedMutation(operation);

  Future<void> _requireIndependentTopic(
    FollowingTopicRepository repository,
    String id,
  ) async {
    final search = await repository.getById(id);
    final folderIds = (await repository.getOrganization()).folders
        .map((folder) => folder.id)
        .toSet();
    if (search == null ||
        (await repository.getFeedMetadata()).any(
          (feed) => !folderIds.contains(feed.id) && feed.sourceIds.contains(id),
        )) {
      throw StateError('Independent followed topic not found');
    }
  }

  TopicOrganization _withoutSharedTopic(
    TopicOrganization organization,
    String searchId,
  ) => TopicOrganization(
    folders: [
      for (final folder in organization.folders)
        TopicFolder(
          id: folder.id,
          name: folder.name,
          feedEnabled: folder.feedEnabled,
          feedMaxPosts: folder.feedMaxPosts,
          parentId: folder.parentId,
          position: folder.position,
          searchIds: folder.searchIds.where((id) => id != searchId),
        ),
    ],
    homeSearchIds: organization.homeSearchIds.where((id) => id != searchId),
  );

  Future<T> runSerializedMutation<T>(
    Future<T> Function(FollowingTopicRepository repository) operation,
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
    final searches = state.valueOrNull?.topics ?? const <FollowingTopic>[];
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

  Future<void> _reload(FollowingTopicRepository repository) async {
    final topics = await repository.getAll();
    _feeds = await repository.getFeeds();
    _organization = await repository.getOrganization();
    if (!_disposed) state = AsyncData(_snapshot(topics));
  }

  void _publishActivity() {
    if (_disposed) return;
    if (state.valueOrNull case final current?) {
      state = AsyncData(_snapshot(current.topics));
    }
  }

  FollowingTopicsState _snapshot(List<FollowingTopic> topics) =>
      FollowingTopicsState(
        topics: topics,
        feeds: List.unmodifiable(_feeds),
        organization: _organization,
        refreshingIds: _inFlight.keys.toSet(),
        pendingRefreshIds: {
          ..._inFlight.keys,
          for (final ids in _refreshPlans.values) ...ids,
        }.intersection(topics.map((item) => item.id).toSet()),
        batchCompleted: _batchCompleted,
        batchTotal: _batchTotal,
        batchProfileId: _batchProfileId,
        refreshingFeedId: _refreshingFeedId,
        feedRefreshChecked: _feedRefreshChecked,
        feedRefreshTotal: _feedRefreshTotal,
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
  final FollowingTopic? definition;
  bool matches(FollowingTopic value) =>
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

class SearchFolderChangedException implements Exception {
  const SearchFolderChangedException(this.organization);
  final TopicOrganization organization;
}
