import 'package:foundation/performance.dart';

// Dart imports:
import 'dart:async';

// Package imports:
import 'package:collection/collection.dart';
import 'package:clock/clock.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../../../../configs/config/src/types/profile_id.dart';
import '../../types/search_post_preview.dart';
import '../../services/conservative_refresh_policy.dart';
import '../../types/search_refresh.dart';
import '../../types/topic_feed.dart';
import '../../types/topic_organization.dart';
import '../../types/following_topic.dart';
import '../../types/following_topic_repository.dart';
import 'recent_search_post_hive_object.dart';
import 'search_post_preview_hive_object.dart';
import 'following_topic_hive_object.dart';

class HiveFollowingTopicRepository implements FollowingTopicRepository {
  HiveFollowingTopicRepository({
    required Box<FollowingTopicHiveObject> box,
    Box<dynamic>? organizationBox,
    Uuid uuid = const Uuid(),
    Clock clock = const Clock(),
  }) : _organizationBox = organizationBox,
       _box = box,
       _uuid = uuid,
       _clock = clock;

  final Box<FollowingTopicHiveObject> _box;
  final Uuid _uuid;
  final Clock _clock;
  final Box<dynamic>? _organizationBox;
  Future<void> _mutationTail = Future.value();

  List<TopicFeed> _feeds() {
    final performanceSpan = performanceRecorder.begin(
      PerfOperation.feedRepositoryRead,
      PerfSpanKind.sync,
    );
    var performanceFailed = false;
    try {
      final feeds = [
        for (final value in _organizationBox?.values ?? const [])
          if (value case final Map json
              when json['id'] is String &&
                  isCanonicalProfileId(json['profileId']) &&
                  json['name'] is String)
            TopicFeed.fromJson({
              ...json,
              if (json['sourceIds'] is! List)
                'sourceIds': [
                  for (final search in _box.values)
                    if (search.feedId == json['id']) search.id,
                ],
            }),
      ];
      final ordered = feeds.indexed.toList()
        ..sort((left, right) {
          final position = left.$2.position.compareTo(right.$2.position);
          return position != 0 ? position : left.$1.compareTo(right.$1);
        });
      return [for (final (_, feed) in ordered) feed];
    } catch (_) {
      performanceFailed = true;
      rethrow;
    } finally {
      performanceSpan.finish(failed: performanceFailed);
    }
  }

  Set<String> _feedSourceIds() {
    final stored = _organizationBox?.get('search:organization');
    final folderIds = <String>{
      if (stored is Map && stored['folders'] is List)
        for (final item in stored['folders'] as List)
          if (item is Map && item['id'] is String) item['id'] as String,
    };
    // Modern folder feeds reference ordinary visible followed topics. Only
    // legacy standalone feeds still own hidden search sources.
    return {
      for (final feed in _feedMetadata())
        if (!folderIds.contains(feed.id)) ...feed.sourceIds,
    };
  }

  List<TopicFeedMetadata> _feedMetadata() {
    final metadata = [
      for (final value in _organizationBox?.values ?? const [])
        if (value case final Map json
            when json['id'] is String &&
                isCanonicalProfileId(json['profileId']) &&
                json['name'] is String)
          TopicFeedMetadata.fromJson({
            ...json,
            if (json['sourceIds'] is! List)
              'sourceIds': [
                for (final search in _box.values)
                  if (search.feedId == json['id']) search.id,
              ],
          }),
    ];
    metadata.sort((left, right) {
      final position = left.position.compareTo(right.position);
      return position != 0 ? position : left.id.compareTo(right.id);
    });
    return metadata;
  }

  @override
  Future<List<TopicFeedMetadata>> getFeedMetadata() =>
      _serialize(() async => _feedMetadata());

  @override
  Future<List<TopicFeed>> getFeeds() => _serialize(() async {
    final feeds = _feeds();
    for (final feed in feeds) {
      if (_organizationBox?.get('feed:${feed.id}') case final Map json
          when json['sourceIds'] is! List) {
        await _organizationBox?.put('feed:${feed.id}', feed.toJson());
      }
    }
    return feeds;
  });

  @override
  Future<bool> migrateLegacyTopicFeeds({
    bool topicsAutoUpdateEnabled = true,
    bool feedsAutoUpdateEnabled = true,
  }) => _serialize(() async {
    final storage = _organizationBox;
    if (storage == null) return false;
    final firstMigration =
        storage.get('search:following_topics_migrated') != true;
    final original = _organization();
    final existingFolderIds = original.folders.map((f) => f.id).toSet();
    // A legacy feed backup can be imported after the first migration. A
    // persisted one-time flag must not hide those later imports.
    final legacy = _feeds()
        .where((feed) => !existingFolderIds.contains(feed.id))
        .toList();
    final claimed = {
      ...original.homeSearchIds,
      for (final folder in original.folders) ...folder.searchIds,
    };
    final usedNames = original.folders
        .where((f) => f.parentId == null)
        .map((f) => f.name.toLowerCase())
        .toSet();
    final newFolders = <TopicFolder>[];
    final feedUpdates = <String, Object?>{};
    final cloned = <String, FollowingTopicHiveObject>{};
    final previousOverrides = storage.get('search:auto_update_overrides');
    final previousEstimates = storage.get('search:new_post_estimates');
    final overrides = <dynamic, dynamic>{
      if (previousOverrides is Map) ...previousOverrides,
    };
    final estimates = <dynamic, dynamic>{
      if (previousEstimates is Map) ...previousEstimates,
    };
    if (firstMigration && !topicsAutoUpdateEnabled) {
      for (final id in claimed) {
        overrides[id] = false;
      }
    }

    String uniqueName(String requested) {
      var name = requested;
      var suffix = 2;
      while (!usedNames.add(name.toLowerCase())) {
        name = '$requested (${suffix++})';
      }
      return name;
    }

    for (final feed in legacy) {
      final ids = <String>[];
      final mapping = <String, String>{};
      for (final id in feed.sourceIds) {
        final sourceObject = _box.get(id);
        if (sourceObject == null) continue;
        var destinationId = id;
        if (!claimed.add(id)) {
          final source = _toTopic(sourceObject);
          destinationId = _uuid.v4();
          cloned[destinationId] = _toObject(
            FollowingTopic(
              id: destinationId,
              profileId: source.profileId,
              query: source.query,
              queryStructure: source.queryStructure,
              name: source.name,
              position: source.position,
              createdAt: source.createdAt,
              previews: source.previews,
              recentPostIdentities: source.recentPostIdentities,
              unreadCount: source.unreadCount,
              lastAttemptAt: source.lastAttemptAt,
              lastSuccessfulCheckAt: source.lastSuccessfulCheckAt,
              highestSeenPostId: source.highestSeenPostId,
              lastErrorKind: source.lastErrorKind,
              runtimeRevision: source.runtimeRevision,
              adaptiveState: source.adaptiveState,
              lastMaterialEditAt: source.lastMaterialEditAt,
            ),
          );
          if (!source.autoUpdateEnabled) overrides[destinationId] = false;
          if (source.newPostCountEstimate case final count?) {
            estimates[destinationId] = {
              'count': count,
              'lowerBound': source.newPostCountIsLowerBound,
            };
          }
          claimed.add(destinationId);
        }
        if (!feedsAutoUpdateEnabled) overrides[destinationId] = false;
        ids.add(destinationId);
        mapping[id] = destinationId;
      }
      newFolders.add(
        TopicFolder(
          id: feed.id,
          name: uniqueName(feed.name),
          position: original.tree.children(null).length + newFolders.length,
          searchIds: ids,
          feedEnabled: true,
          feedMaxPosts: feed.maxPosts,
        ),
      );
      final migrated = TopicFeed(
        id: feed.id,
        profileId: feed.profileId,
        name: newFolders.last.name,
        position: feed.position,
        maxPosts: feed.maxPosts,
        sourceIds: ids,
        posts: feed.posts,
        initializedSourceIds: [
          for (final id in feed.initializedSourceIds) ?mapping[id],
        ],
        postSources: {
          for (final entry in feed.postSources.entries)
            entry.key: [
              for (final id in entry.value) ?mapping[id],
            ],
        },
      );
      feedUpdates['feed:${feed.id}'] = migrated.toJson();
    }
    final previouslyStored = storage.get('search:organization');
    final originals = {
      for (final feed in legacy)
        'feed:${feed.id}': storage.get('feed:${feed.id}'),
    };
    try {
      await _box.putAll(cloned);
      await storage.put(
        'search:organization',
        TopicOrganization(
          folders: [...original.folders, ...newFolders],
          homeSearchIds: original.homeSearchIds,
        ).toJson(),
      );
      await storage.putAll({
        ...feedUpdates,
        'search:auto_update_overrides': overrides,
        'search:new_post_estimates': estimates,
      });
      await storage.put('search:following_topics_migrated', true);
      return firstMigration;
    } catch (_) {
      if (previouslyStored == null) {
        await storage.delete('search:organization');
      } else {
        await storage.put('search:organization', previouslyStored);
      }
      await storage.putAll(originals);
      for (final entry in {
        'search:auto_update_overrides': previousOverrides,
        'search:new_post_estimates': previousEstimates,
      }.entries) {
        if (entry.value == null) {
          await storage.delete(entry.key);
        } else {
          await storage.put(entry.key, entry.value);
        }
      }
      await _box.deleteAll(cloned.keys);
      rethrow;
    }
  });

  @override
  Future<TopicFeed?> ensureFolderFeed(
    String folderId, {
    String? fallbackProfileId,
  }) => _serialize(() async {
    final storage = _organizationBox;
    if (storage == null) return null;
    final organization = _organization();
    final folder = organization.folders
        .where((f) => f.id == folderId && f.feedEnabled)
        .firstOrNull;
    if (folder == null) return null;
    final ids = organization.recursiveIds(folderId);
    final first = ids.isEmpty ? null : _box.get(ids.first);
    if (ids.isNotEmpty && first == null) return null;
    final existing = _feeds().where((f) => f.id == folderId).firstOrNull;
    // A folder with no topics has no origin of its own. Retain its previous
    // profile or use a configured profile only as the legacy cache anchor.
    final profileId =
        first?.profileId ?? existing?.profileId ?? fallbackProfileId;
    if (profileId == null) return null;
    final updated = existing == null
        ? TopicFeed(
            id: folder.id,
            profileId: profileId,
            name: folder.name,
            sourceIds: ids,
            maxPosts: folder.feedMaxPosts,
          )
        : existing
              .reconcileSources(ids)
              .copyWith(
                name: folder.name,
                profileId: profileId,
                maxPosts: folder.feedMaxPosts,
              );
    await storage.put('feed:${folder.id}', updated.toJson());
    return updated;
  });

  @override
  Future<void> clearAllFeedCaches() => _serialize(() async {
    final storage = _organizationBox;
    if (storage == null) return;
    final folderIds = _organization().folders
        .map((folder) => folder.id)
        .toSet();
    final feeds = _feeds();
    final previous = {
      for (final feed in feeds)
        'feed:${feed.id}': storage.get('feed:${feed.id}'),
    };
    try {
      for (final feed in feeds) {
        final key = 'feed:${feed.id}';
        if (folderIds.contains(feed.id)) {
          await storage.delete(key);
        } else {
          await storage.put(
            key,
            feed
                .copyWith(
                  posts: const [],
                  postSources: const {},
                  initializedSourceIds: const [],
                )
                .toJson(),
          );
        }
      }
    } catch (_) {
      for (final entry in previous.entries) {
        if (entry.value == null) {
          await storage.delete(entry.key);
        } else {
          await storage.put(entry.key, entry.value);
        }
      }
      rethrow;
    }
  });

  @override
  Future<void> clearFolderFeedCache(String folderId) => _serialize(() async {
    final organization = _organization();
    if (!organization.folders.any((f) => f.id == folderId)) {
      throw StateError('Folder not found');
    }
    await _organizationBox?.delete('feed:$folderId');
  });

  @override
  Future<TopicFeed> saveFeed({
    required String profileId,
    required String name,
    required List<String> queries,
    String? id,
  }) => _serialize(() async {
    final storage = _organizationBox;
    if (storage == null) throw StateError('Feed storage unavailable');
    final normalized = queries
        .map(normalizeSearchIdentity)
        .where((query) => query.isNotEmpty)
        .toSet()
        .toList();
    if (name.trim().isEmpty ||
        normalized.isEmpty ||
        normalized.length > topicFeedSourceLimit) {
      throw const FormatException('Invalid feed definition');
    }
    final feeds = _feeds();
    final previous = id == null
        ? null
        : feeds.where((f) => f.id == id).firstOrNull;
    if (previous != null && previous.profileId != profileId) {
      throw StateError('Feed ownership mismatch');
    }
    final feedId = previous?.id ?? id ?? _uuid.v4();
    if (_organization().folders.any((folder) => folder.id == feedId)) {
      throw StateError('Folder feeds must be edited through their Topics');
    }
    final all = _topics().toList();
    final internalIds = _feedSourceIds();
    final internalByQuery = <String, FollowingTopic>{
      for (final search in all)
        if (internalIds.contains(search.id) && search.profileId == profileId)
          normalizeSearchIdentity(search.query): search,
    };
    final retained = <FollowingTopic>[];
    for (final (position, query) in normalized.indexed) {
      final existing = internalByQuery[query];
      retained.add(
        existing ??
            FollowingTopic.create(
              id: _uuid.v4(),
              profileId: profileId,
              query: query,
              name: null,
              position: position,
              createdAt: _clock.now().toUtc(),
            ),
      );
    }
    final retainedIds = retained.map((source) => source.id).toSet();
    final removedIds =
        previous?.sourceIds.toSet().difference(retainedIds) ?? <String>{};
    final otherIds = {
      for (final feed in feeds)
        if (feed.id != feedId) ...feed.sourceIds,
    };
    final orphans = removedIds.difference(otherIds);
    final oldSources = {
      for (final source in all)
        if (orphans.contains(source.id)) source.id: _toObject(source),
    };
    final createdIds = retainedIds.difference(
      all.map((source) => source.id).toSet(),
    );
    final feed =
        (previous ??
                TopicFeed(
                  id: feedId,
                  profileId: profileId,
                  name: name.trim(),
                  position: feeds.where((f) => f.profileId == profileId).length,
                ))
            .reconcileSources(retained.map((source) => source.id).toList())
            .copyWith(name: name.trim());
    await storage.put('feed:$feedId', feed.toJson());
    try {
      await _box.putAll({
        for (final source in retained)
          if (createdIds.contains(source.id)) source.id: _toObject(source),
      });
      await _box.deleteAll(orphans);
    } catch (_) {
      await _box.deleteAll(createdIds);
      await _box.putAll(oldSources);
      if (previous == null) {
        await storage.delete('feed:$feedId');
      } else {
        await storage.put('feed:$feedId', previous.toJson());
      }
      rethrow;
    }
    return feed;
  });

  @override
  Future<void> deleteFeed(String id) => _serialize(() async {
    final feeds = _feeds();
    final feed = feeds.where((item) => item.id == id).firstOrNull;
    if (feed == null) return;
    if (_organization().folders.any((folder) => folder.id == id)) {
      await _organizationBox?.delete('feed:$id');
      return;
    }
    final referencedElsewhere = {
      for (final item in feeds)
        if (item.id != id) ...item.sourceIds,
    };
    final orphanIds = feed.sourceIds.toSet().difference(referencedElsewhere);
    final sources = {
      for (final source in _topics())
        if (orphanIds.contains(source.id)) source.id: _toObject(source),
    };
    await _organizationBox?.delete('feed:$id');
    try {
      await _box.deleteAll(orphanIds);
    } catch (_) {
      await _organizationBox?.put('feed:$id', feed.toJson());
      await _box.putAll(sources);
      rethrow;
    }
  });

  @override
  Future<void> setFeedOrder(String profileId, List<String> orderedIds) =>
      _serialize(() async {
        final storage = _organizationBox;
        if (storage == null) throw StateError('Feed storage unavailable');
        final feeds = _feeds().where((f) => f.profileId == profileId).toList();
        final ids = feeds.map((f) => f.id).toSet();
        if (orderedIds.length != feeds.length ||
            orderedIds.toSet().length != feeds.length ||
            !ids.containsAll(orderedIds)) {
          throw const FormatException('Incomplete feed order');
        }
        final byId = {for (final feed in feeds) feed.id: feed};
        final previous = {
          for (final id in orderedIds) 'feed:$id': storage.get('feed:$id'),
        };
        try {
          await storage.putAll({
            for (final (position, id) in orderedIds.indexed)
              'feed:$id': byId[id]!.copyWith(position: position).toJson(),
          });
        } catch (_) {
          await storage.putAll(previous);
          rethrow;
        }
      });

  @override
  Future<void> restoreFeeds(
    String profileId,
    List<TopicFeed> feeds,
  ) => _serialize(() async {
    if (feeds.any((f) => f.profileId != profileId)) {
      throw StateError('Invalid feed ownership');
    }
    await _organizationBox?.deleteAll(
      _feeds()
          .where((f) => f.profileId == profileId)
          .map((f) => 'feed:${f.id}'),
    );
    await _organizationBox?.putAll({
      for (final f in feeds) 'feed:${f.id}': f.toJson(),
    });
  });

  @override
  Future<void> invalidateRuntimeForProfile(String profileId) =>
      _serialize(() async {
        final originals = {
          for (final object in _box.values)
            if (object.profileId == profileId) object.id: object,
        };
        final feeds = _feeds().where(
          (feed) => feed.sourceIds.any(originals.containsKey),
        );
        final originalFeeds = {
          for (final feed in feeds)
            'feed:${feed.id}': _organizationBox?.get('feed:${feed.id}'),
        };
        final resetSearches = {
          for (final object in originals.values)
            object.id: _toObject(_resetRuntime(_toTopic(object))),
        };
        try {
          await _box.putAll(resetSearches);
          await _organizationBox?.putAll({
            for (final feed in feeds)
              'feed:${feed.id}': feed
                  .reconcileSources(
                    feed.sourceIds
                        .where((id) => !originals.containsKey(id))
                        .toList(),
                  )
                  .copyWith(
                    sourceIds: feed.sourceIds,
                    posts: feed
                        .reconcileSources(
                          feed.sourceIds
                              .where((id) => !originals.containsKey(id))
                              .toList(),
                        )
                        .posts
                        .where(
                          (post) =>
                              feed.postSources.containsKey(
                                feedPostIdentity(post),
                              ) ||
                              post.origin.profileIdHint != profileId,
                        )
                        .toList(),
                  )
                  .toJson(),
          });
        } catch (_) {
          await _box.putAll(originals);
          await _organizationBox?.putAll({
            for (final entry in originalFeeds.entries)
              if (entry.value != null) entry.key: entry.value,
          });
          rethrow;
        }
      });

  FollowingTopic _resetRuntime(FollowingTopic source) => FollowingTopic(
    id: source.id,
    profileId: source.profileId,
    query: source.query,
    queryStructure: source.queryStructure,
    name: source.name,
    position: source.position,
    createdAt: source.createdAt,
    runtimeRevision: source.runtimeRevision + 1,
    lastMaterialEditAt: _clock.now().toUtc(),
    previews: const [],
    recentPostIdentities: const [],
    unreadCount: 0,
  );

  @override
  Future<TopicOrganization> getOrganization() => _serialize(() async {
    final organization = _organization();
    if (_organizationBox?.get('search:organization') case final Map json
        when json['version'] != 2) {
      await _organizationBox?.put('search:organization', organization.toJson());
    }
    return organization;
  });

  @override
  Future<void> replaceOrganization(TopicOrganization organization) =>
      _serialize(() async {
        final storage = _organizationBox;
        if (storage == null) {
          throw StateError('Organization storage unavailable');
        }
        try {
          organization.tree.validatePlacements(organization.placements);
        } on FormatException catch (e) {
          throw StateError(e.message);
        }
        final folderIds = <String>{};
        final folderNames = <(String?, String)>{};
        final memberships = <String>{};
        final topics = {
          for (final topic in _topics()) topic.id: topic,
        };

        for (final folder in organization.folders) {
          if (!folderIds.add(folder.id) ||
              !folderNames.add((folder.parentId, folder.name.toLowerCase()))) {
            throw StateError('Duplicate shared search folder');
          }
          _validateOrganizationMemberships(
            folder.searchIds,
            memberships,
            topics,
          );
        }
        _validateOrganizationMemberships(
          organization.homeSearchIds,
          memberships,
          topics,
        );
        final oldOrganization = storage.get('search:organization');
        final oldFeeds = {
          for (final feed in _feeds())
            if (organization.folders.any((f) => f.id == feed.id))
              feed.id: storage.get('feed:${feed.id}'),
        };
        try {
          await storage.put('search:organization', organization.toJson());
          for (final feed in _feeds()) {
            final folder = organization.folders
                .where((f) => f.id == feed.id)
                .firstOrNull;
            if (folder == null) continue;
            final sourceIds = organization.recursiveIds(folder.id);
            final reconciled = feed.reconcileSources(sourceIds);
            final updated = reconciled.copyWith(
              name: folder.name,
              profileId: sourceIds.isEmpty
                  ? feed.profileId
                  : _box.get(sourceIds.first)?.profileId ?? feed.profileId,
              maxPosts: folder.feedMaxPosts,
              // Raising the limit must make the next refresh backfill each
              // source instead of treating the smaller cache as complete.
              initializedSourceIds: folder.feedMaxPosts > feed.maxPosts
                  ? const []
                  : reconciled.initializedSourceIds,
            );
            if (updated != feed) {
              await storage.put('feed:${feed.id}', updated.toJson());
            }
          }
        } catch (_) {
          if (oldOrganization != null) {
            await storage.put('search:organization', oldOrganization);
          } else {
            await storage.delete('search:organization');
          }
          for (final entry in oldFeeds.entries) {
            if (entry.value != null) {
              await storage.put('feed:${entry.key}', entry.value);
            }
          }
          rethrow;
        }
      });

  @override
  Future<void> deleteSharedFolderAndTopics(String folderId) => _serialize(
    () async {
      final storage = _organizationBox;
      if (storage == null) throw StateError('Organization storage unavailable');
      final previousOrganization = _organization();
      final folder = previousOrganization.folders
          .where((folder) => folder.id == folderId)
          .firstOrNull;
      if (folder == null) return;
      final previousTopics = {
        for (final id in previousOrganization.recursiveIds(folderId))
          id: ?_box.get(id),
      };
      final nextOrganization = TopicOrganization(
        folders: previousOrganization.folders.where(
          (item) =>
              !previousOrganization.tree.subtree(folderId).contains(item.id),
        ),
        homeSearchIds: previousOrganization.homeSearchIds,
      );
      final removed = previousOrganization.tree.subtree(folderId);
      final affected = _feeds()
          .where(
            (feed) => previousOrganization.folders.any((f) => f.id == feed.id),
          )
          .toList();
      final priorCaches = {
        for (final feed in affected)
          'feed:${feed.id}': storage.get('feed:${feed.id}'),
      };
      try {
        await _box.deleteAll(previousTopics.keys);
        await storage.put('search:organization', nextOrganization.toJson());
        for (final feed in affected) {
          if (removed.contains(feed.id)) {
            await storage.delete('feed:${feed.id}');
          } else {
            final reconciled = feed.reconcileSources(
              nextOrganization.recursiveIds(feed.id),
            );
            if (reconciled != feed) {
              await storage.put('feed:${feed.id}', reconciled.toJson());
            }
          }
        }
      } catch (_) {
        await _box.putAll(previousTopics);
        await storage.put('search:organization', previousOrganization.toJson());
        await storage.putAll({
          for (final entry in priorCaches.entries)
            if (entry.value != null) entry.key: entry.value,
        });
        rethrow;
      }
    },
  );

  @override
  Future<List<FollowingTopic>> getAll() {
    return _read(() => _topics().toList());
  }

  @override
  Future<FollowingTopic?> getById(String id) {
    return _read(() {
      final object = _box.get(id.trim());
      return object == null ? null : _toTopic(object);
    });
  }

  @override
  Future<FollowingTopic?> findByQuery(String profileId, String query) =>
      _read(() => _findIndependentByQuery(profileId, query));

  FollowingTopic? _findIndependentByQuery(
    String profileId,
    String query, {
    String? excludingId,
  }) {
    final normalizedQuery = normalizeSearchIdentity(query);
    final internalIds = _feedSourceIds();
    return _topics().firstWhereOrNull(
      (topic) =>
          topic.id != excludingId &&
          topic.profileId == profileId &&
          !internalIds.contains(topic.id) &&
          normalizeSearchIdentity(topic.query) == normalizedQuery,
    );
  }

  @override
  Future<FollowingTopic> create({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    required String? name,
    String? id,
    DateTime? createdAt,
  }) {
    return _serialize(() async {
      final normalizedQuery = normalizeSearchIdentity(query);
      if (normalizedQuery.isEmpty) {
        throw const FormatException('Followed topic queries cannot be empty.');
      }
      final topics = _topics().toList();
      final internalIds = _feedSourceIds();
      final topicId = (id ?? _uuid.v4()).trim().toLowerCase();
      if (topicId.isEmpty) {
        throw const FormatException('Followed topic IDs cannot be empty.');
      }
      if (_box.containsKey(topicId)) {
        throw StateError('Followed topic $topicId already exists.');
      }
      final topic = FollowingTopic.create(
        id: topicId,
        profileId: profileId,
        query: query,
        queryStructure: queryStructure,
        name: name,
        position: topics
            .where(
              (topic) =>
                  topic.profileId == profileId &&
                  !internalIds.contains(topic.id),
            )
            .fold(
              0,
              (next, item) => item.position >= next ? item.position + 1 : next,
            ),
        createdAt: createdAt ?? _clock.now().toUtc(),
      );
      final object = _toObject(topic);
      final storage = _organizationBox;
      final originals = <String, Object?>{
        if (storage != null)
          for (final key in [
            'search:auto_update_overrides',
            'search:new_post_estimates',
          ])
            key: storage.get(key),
      };
      try {
        // Backup IDs may be reused after deletion. New topic records must not
        // inherit an old record's sidecar preferences or unread estimates.
        if (storage != null) {
          await storage.putAll({
            for (final entry in originals.entries)
              entry.key: <dynamic, dynamic>{
                ...?(entry.value as Map?),
              }..remove(topic.id),
          });
        }
        await _box.put(topic.id, object);
      } catch (_) {
        await _box.delete(topic.id);
        if (storage != null) {
          for (final entry in originals.entries) {
            if (entry.value == null) {
              await storage.delete(entry.key);
            } else {
              await storage.put(entry.key, entry.value);
            }
          }
        }
        rethrow;
      }
      return _toTopic(object);
    });
  }

  @override
  Future<FollowingTopic> edit(
    String id, {
    required String profileId,
    required String query,
    required String? name,
  }) => _serialize(() async {
    final current = _toTopic(_requireObject(id));
    if (_feedSourceIds().contains(current.id)) {
      throw StateError('Feed sources cannot be edited as followed topics.');
    }
    final trimmedQuery = query.trim();
    final normalizedQuery = normalizeSearchIdentity(trimmedQuery);
    if (normalizedQuery.isEmpty) {
      throw const FormatException('Followed topic queries cannot be empty.');
    }
    // Equal searches in different folders are independent topics. Only
    // direct siblings should be prevented from accidental duplication.
    final organization = _organization();
    final currentFolderId = organization.placements
        .where((p) => p.itemId == current.id)
        .firstOrNull
        ?.folderId;
    final duplicateInSameFolder = _topics().any(
      (search) =>
          search.id != current.id &&
          search.profileId == profileId &&
          normalizeSearchIdentity(search.query) == normalizedQuery &&
          organization.placements.any(
            (p) => p.itemId == search.id && p.folderId == currentFolderId,
          ),
    );
    if (duplicateInSameFolder) {
      throw DuplicateFollowingTopicException();
    }

    final material =
        current.profileId != profileId || current.query != trimmedQuery;
    final updated = material
        ? FollowingTopic(
            id: current.id,
            profileId: profileId,
            query: trimmedQuery,
            queryStructure: current.query == trimmedQuery
                ? current.queryStructure
                : null,
            name: name,
            position: current.position,
            createdAt: current.createdAt,
            runtimeRevision: current.runtimeRevision + 1,
            lastMaterialEditAt: _clock.now().toUtc(),
            previews: const [],
            recentPostIdentities: const [],
            unreadCount: 0,
          )
        : current.copyWithName(name);
    final object = _toObject(updated);
    final feeds = material
        ? _feeds().where((feed) => feed.sourceIds.contains(id)).toList()
        : const <TopicFeed>[];
    final saved = {
      for (final feed in feeds)
        'feed:${feed.id}': _organizationBox?.get('feed:${feed.id}'),
    };
    try {
      await _box.put(object.id, object);
      for (final feed in feeds) {
        final filtered = feed
            .reconcileSources(
              feed.sourceIds.where((sourceId) => sourceId != id).toList(),
            )
            .copyWith(sourceIds: feed.sourceIds);
        await _organizationBox?.put(
          'feed:${feed.id}',
          filtered.toJson(),
        );
      }
    } catch (_) {
      await _box.put(current.id, _toObject(current));
      await _organizationBox?.putAll({
        for (final entry in saved.entries)
          if (entry.value != null) entry.key: entry.value,
      });
      rethrow;
    }
    return _toTopic(object);
  });

  @override
  Future<FollowingTopic> rename(String id, String? name) {
    return _serialize(() async {
      final current = _requireObject(id);
      final updated = _toTopic(current).copyWithName(name);
      final object = _toObject(updated);
      await _box.put(object.id, object);
      return _toTopic(object);
    });
  }

  @override
  Future<FollowingTopic> saveTopicInNewFolder({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    required String? name,
    required String folderName,
    String? parentFolderId,
    bool feedEnabled = false,
    int feedMaxPosts = topicFeedRetention,
    String? existingTopicId,
  }) => _serialize(() async {
    final storage = _organizationBox;
    if (storage == null) throw StateError('Organization storage unavailable');
    final identity = normalizeSearchIdentity(query);
    if (identity.isEmpty) throw const FormatException('Empty topic query');
    final current = _organization();
    if (parentFolderId != null &&
        !current.folders.any((folder) => folder.id == parentFolderId)) {
      throw StateError('Parent folder not found');
    }
    if (feedMaxPosts < 1) {
      throw ArgumentError.value(feedMaxPosts, 'feedMaxPosts');
    }
    final folder = TopicFolder(
      id: _uuid.v4(),
      name: folderName,
      parentId: parentFolderId,
      feedEnabled: feedEnabled,
      feedMaxPosts: feedMaxPosts,
      position: current.tree.children(parentFolderId).length,
    );
    if (current.folders.any(
      (f) =>
          f.parentId == parentFolderId &&
          f.name.toLowerCase() == folder.name.toLowerCase(),
    )) {
      throw StateError('Duplicate shared search folder');
    }
    final topics = _topicsForProfile(profileId).toList();
    final existing = existingTopicId == null
        ? null
        : topics.firstWhereOrNull(
            (topic) =>
                topic.id == existingTopicId &&
                normalizeSearchIdentity(topic.query) == identity,
          );
    if (existingTopicId != null && existing == null) {
      throw StateError('Independent followed topic not found');
    }
    final topic = switch (existing) {
      final topic? => name == null ? topic : topic.copyWithName(name),
      null => FollowingTopic.create(
        id: _uuid.v4(),
        profileId: profileId,
        query: query,
        queryStructure: queryStructure,
        name: name,
        position: topics.fold(
          0,
          (next, topic) => topic.position >= next ? topic.position + 1 : next,
        ),
        createdAt: _clock.now().toUtc(),
      ),
    };
    final next = TopicOrganization(
      folders: [
        for (final old in current.folders)
          TopicFolder(
            id: old.id,
            name: old.name,
            feedEnabled: old.feedEnabled,
            feedMaxPosts: old.feedMaxPosts,
            parentId: old.parentId,
            position: old.position,
            searchIds: old.searchIds.where((id) => id != topic.id),
          ),
        TopicFolder(
          id: folder.id,
          name: folder.name,
          feedEnabled: folder.feedEnabled,
          feedMaxPosts: folder.feedMaxPosts,
          parentId: folder.parentId,
          position: folder.position,
          searchIds: [topic.id],
        ),
      ],
      homeSearchIds: current.homeSearchIds.where((id) => id != topic.id),
    );
    final previousTopic = _box.get(topic.id);
    final previousOrganization = storage.get('search:organization');
    try {
      await _box.put(topic.id, _toObject(topic));
      await storage.put('search:organization', next.toJson());
    } catch (_) {
      if (previousTopic case final topic?) {
        await _box.put(topic.id, topic);
      } else {
        await _box.delete(topic.id);
      }
      // A write can report failure after changing storage.
      if (storage.get('search:organization') != previousOrganization) {
        if (previousOrganization case final value?) {
          await storage.put('search:organization', value);
        } else {
          await storage.delete('search:organization');
        }
      }
      rethrow;
    }
    return topic;
  });

  @override
  Future<List<FollowingTopic>> reorder(
    String profileId,
    int oldIndex,
    int newIndex,
  ) {
    return _serialize(() async {
      final topics = _topicsForProfile(profileId).toList();
      if (oldIndex < 0 || oldIndex >= topics.length) {
        throw RangeError.index(oldIndex, topics, 'oldIndex');
      }
      if (newIndex < 0 || newIndex >= topics.length) {
        throw RangeError.index(newIndex, topics, 'newIndex');
      }
      final moved = topics.removeAt(oldIndex);
      topics.insert(newIndex, moved);
      final objects = <String, FollowingTopicHiveObject>{
        for (var index = 0; index < topics.length; index++)
          topics[index].id: _toObject(
            topics[index].copyWithPosition(index),
          ),
      };
      await _box.putAll(objects);
      return objects.values.map(_toTopic).toList();
    });
  }

  @override
  Future<void> setAutoUpdate(Iterable<String> ids, bool enabled) =>
      _serialize(() async {
        final storage = _organizationBox;
        if (storage == null) throw StateError('Topic settings unavailable');
        final known = _topics().map((source) => source.id).toSet();
        final selected = ids.toSet();
        if (!known.containsAll(selected)) {
          throw StateError('Topic not found');
        }
        final previous = storage.get('search:auto_update_overrides');
        final overrides = <String, bool>{
          if (previous is Map)
            for (final entry in previous.entries)
              if (entry.key is String && entry.value == false)
                entry.key as String: false,
        };
        for (final id in selected) {
          if (enabled) {
            overrides.remove(id);
          } else {
            overrides[id] = false;
          }
        }
        await storage.put('search:auto_update_overrides', overrides);
      });

  @override
  Future<FollowingTopic?> markRead(String id) {
    return _serialize(() async {
      final current = _box.get(id.trim());
      if (current == null) {
        return null;
      }
      final updated = _toTopic(current).copyWithUnreadCount(0);
      final object = _toObject(updated);
      final rawEstimates = _organizationBox?.get('search:new_post_estimates');
      final estimates = <String, Object?>{
        if (rawEstimates is Map)
          for (final entry in rawEstimates.entries)
            if (entry.key is String) entry.key as String: entry.value,
      };
      try {
        await _box.put(object.id, object);
        if (estimates.remove(object.id) != null) {
          await _organizationBox?.put('search:new_post_estimates', estimates);
        }
      } catch (_) {
        await _box.put(current.id, current);
        if (rawEstimates != null) {
          await _organizationBox?.put(
            'search:new_post_estimates',
            rawEstimates,
          );
        } else {
          await _organizationBox?.delete('search:new_post_estimates');
        }
        rethrow;
      }
      return _toTopic(object);
    });
  }

  @override
  Future<FollowingTopic?> commitRefresh(SearchRefreshCommit commit) {
    return _serialize(() async {
      if (!(commit.canCommit?.call() ?? true)) return null;
      final currentObject = _box.get(commit.topicId.trim());
      if (currentObject == null) {
        return null;
      }
      final current = _toTopic(currentObject);
      if (current.createdAt != commit.expectedCreatedAt ||
          current.runtimeRevision != commit.expectedRevision ||
          current.lastSuccessfulCheckAt != commit.expectedCheckpoint) {
        return null;
      }

      final knownPostIds = current.recentPostIdentities
          .map((identity) => identity.postId)
          .toSet();
      final newlyDiscovered = <SearchPostPreview>[];
      for (final preview in commit.discoveredPosts) {
        if (knownPostIds.add(preview.postId)) {
          newlyDiscovered.add(preview);
        }
      }

      final previews = _mergePreviews(
        commit.discoveredPosts,
        commit.delta ? current.previews : const [],
      );
      final highestSeenPostId = commit.discoveredPosts.fold<int>(
        current.highestSeenPostId ?? -1,
        (highest, post) => post.postId > highest ? post.postId : highest,
      );
      final foundHigherId = switch (current.highestSeenPostId) {
        final previousId? => highestSeenPostId > previousId,
        _ => false,
      };
      final recentPostIdentities =
          [
                ...current.recentPostIdentities,
                ...newlyDiscovered
                    .where(
                      (preview) => preview.postCreatedAt != null,
                    )
                    .map(
                      (preview) => RecentSearchPostIdentity(
                        postId: preview.postId,
                        postCreatedAt: preview.postCreatedAt!,
                      ),
                    ),
              ]
              .where(
                (identity) => !identity.postCreatedAt.isBefore(
                  commit.identityRetentionBoundary,
                ),
              )
              .toList()
            ..sort(
              (left, right) =>
                  right.postCreatedAt.compareTo(left.postCreatedAt),
            );
      final updated = FollowingTopic(
        id: current.id,
        profileId: current.profileId,
        query: current.query,
        queryStructure: current.queryStructure,
        name: current.name,
        position: current.position,
        createdAt: current.createdAt,
        runtimeRevision: current.runtimeRevision,
        lastMaterialEditAt: current.lastMaterialEditAt,
        adaptiveState: current.adaptiveState.after(
          !commit.automatic || commit.baseline
              ? AdaptiveRefreshResult.baseline
              : foundHigherId
              ? AdaptiveRefreshResult.newPostsAutomatic
              : AdaptiveRefreshResult.emptyAutomatic,
        ),
        previews: previews,
        recentPostIdentities: recentPostIdentities.take(50).toList(),
        highestSeenPostId: highestSeenPostId,
        unreadCount: !commit.baseline && (current.hasNewPosts || foundHigherId)
            ? 1
            : 0,
        lastAttemptAt: commit.startedAt,
        lastSuccessfulCheckAt: commit.startedAt,
      );
      final object = _toObject(updated);
      final folderStates = {
        for (final folder in _organization().folders) folder.id: folder,
      };
      final referencingFeeds = _feeds()
          .where(
            (feed) =>
                feed.sourceIds.contains(current.id) &&
                (folderStates[feed.id]?.feedEnabled ?? true),
          )
          .toList();
      final previousFeeds = <String, Object?>{
        for (final feed in referencingFeeds)
          feed.id: _organizationBox?.get('feed:${feed.id}'),
      };
      final rawEstimates = _organizationBox?.get('search:new_post_estimates');
      final estimates = <String, Object?>{
        if (rawEstimates is Map)
          for (final entry in rawEstimates.entries)
            if (entry.key is String) entry.key as String: entry.value,
      };
      final newCount = !commit.baseline && current.highestSeenPostId != null
          ? commit.discoveredPosts
                .where((post) => post.postId > current.highestSeenPostId!)
                .length
          : 0;
      final previousEstimate = estimates[current.id];
      final previousCount =
          current.hasNewPosts &&
              previousEstimate is Map &&
              previousEstimate['count'] is int
          ? previousEstimate['count'] as int
          : 0;
      final saveEstimate = newCount > 0 && _organizationBox != null;
      if (saveEstimate) {
        estimates[current.id] = {
          'count': (previousCount + newCount).clamp(0, 1000000000),
          'lowerBound':
              commit.truncated ||
              (current.hasNewPosts && previousEstimate == null) ||
              (previousEstimate is Map &&
                  previousEstimate['lowerBound'] == true),
        };
      }
      try {
        for (final feed in referencingFeeds) {
          await _organizationBox?.put(
            'feed:${feed.id}',
            feed.merge(commit.feedPosts, sourceId: current.id).toJson(),
          );
        }
        if (saveEstimate) {
          await _organizationBox.put('search:new_post_estimates', estimates);
        }
        await _box.put(object.id, object);
      } catch (_) {
        for (final entry in previousFeeds.entries) {
          if (entry.value != null) {
            await _organizationBox?.put('feed:${entry.key}', entry.value);
          }
        }
        if (saveEstimate) {
          if (rawEstimates != null) {
            await _organizationBox.put(
              'search:new_post_estimates',
              rawEstimates,
            );
          } else {
            await _organizationBox.delete('search:new_post_estimates');
          }
        }
        rethrow;
      }
      return _toTopic(object);
    });
  }

  @override
  Future<FollowingTopic?> recordRefreshFailure(
    String id, {
    required DateTime expectedCreatedAt,
    int expectedRevision = 0,
    required DateTime attemptedAt,
    required SearchRefreshErrorKind kind,
    bool Function()? canCommit,
  }) {
    return _serialize(() async {
      if (!(canCommit?.call() ?? true)) return null;
      final current = _box.get(id.trim());
      if (current == null ||
          current.createdAt != expectedCreatedAt ||
          current.runtimeRevision != expectedRevision) {
        return null;
      }
      final topic = _toTopic(current);
      final updated = FollowingTopic(
        id: topic.id,
        profileId: topic.profileId,
        query: topic.query,
        queryStructure: topic.queryStructure,
        name: topic.name,
        position: topic.position,
        createdAt: topic.createdAt,
        runtimeRevision: topic.runtimeRevision,
        adaptiveState: topic.adaptiveState,
        lastMaterialEditAt: topic.lastMaterialEditAt,
        previews: topic.previews,
        recentPostIdentities: topic.recentPostIdentities,
        unreadCount: topic.unreadCount,
        lastAttemptAt: attemptedAt,
        lastSuccessfulCheckAt: topic.lastSuccessfulCheckAt,
        highestSeenPostId: topic.highestSeenPostId,
        lastErrorKind: kind,
      );
      final object = _toObject(updated);
      await _box.put(object.id, object);
      return _toTopic(object);
    });
  }

  @override
  Future<void> delete(String id) {
    return _serialize(() async {
      final current = _box.get(id.trim());
      if (current == null) {
        return;
      }
      final previousOrganization = _organization();
      final previousTopics = {
        for (final topic in _topics())
          if (topic.profileId == current.profileId) topic.id: _toObject(topic),
      };
      final nextOrganization = _removeOrganizationMemberships(
        previousOrganization,
        {current.id},
      );
      final affected = _feeds()
          .where(
            (feed) => previousOrganization.folders.any((f) => f.id == feed.id),
          )
          .toList();
      final cached = {
        for (final feed in affected)
          'feed:${feed.id}': _organizationBox?.get('feed:${feed.id}'),
      };
      try {
        await _organizationBox?.put(
          'search:organization',
          nextOrganization.toJson(),
        );
        for (final feed in affected) {
          final reconciled = feed.reconcileSources(
            nextOrganization.recursiveIds(feed.id),
          );
          if (reconciled != feed) {
            await _organizationBox?.put(
              'feed:${feed.id}',
              reconciled.toJson(),
            );
          }
        }
        await _box.delete(current.id);
        await _writeContiguousPositions(current.profileId);
      } catch (_) {
        await _box.putAll(previousTopics);
        await _organizationBox?.put(
          'search:organization',
          previousOrganization.toJson(),
        );
        await _organizationBox?.putAll({
          for (final entry in cached.entries)
            if (entry.value != null) entry.key: entry.value,
        });
        rethrow;
      }
    });
  }

  @override
  Future<void> deleteForProfile(String profileId) {
    return _serialize(() async {
      final keys = _box.values
          .where((object) => object.profileId == profileId)
          .map((object) => object.id)
          .toList();
      final previousTopics = {
        for (final id in keys) id: ?_box.get(id),
      };
      final previousOrganization = _organization();
      final nextOrganization = _removeOrganizationMemberships(
        previousOrganization,
        keys.toSet(),
      );
      final previous = _organizationBox?.get(profileId);
      final folderIds = previousOrganization.folders.map((f) => f.id).toSet();
      final feeds = _feeds();
      final legacyToDelete = feeds
          .where(
            (feed) =>
                !folderIds.contains(feed.id) && feed.profileId == profileId,
          )
          .toList();
      final folderFeeds = feeds
          .where(
            (feed) => folderIds.contains(feed.id),
          )
          .toList();
      final originals = {
        for (final feed in [...legacyToDelete, ...folderFeeds])
          'feed:${feed.id}': _organizationBox?.get('feed:${feed.id}'),
      };
      try {
        await _organizationBox?.deleteAll(
          legacyToDelete.map((feed) => 'feed:${feed.id}'),
        );
        await _organizationBox?.delete(profileId);
        await _organizationBox?.put(
          'search:organization',
          nextOrganization.toJson(),
        );
        await _box.deleteAll(keys);
        for (final feed in folderFeeds) {
          final ids = nextOrganization.recursiveIds(feed.id);
          final updated = feed
              .reconcileSources(ids)
              .copyWith(
                profileId: ids.isEmpty
                    ? feed.profileId
                    : _box.get(ids.first)?.profileId ?? feed.profileId,
              );
          await _organizationBox?.put('feed:${feed.id}', updated.toJson());
        }
      } catch (_) {
        await _box.putAll(previousTopics);
        if (previous != null) await _organizationBox?.put(profileId, previous);
        await _organizationBox?.putAll({
          for (final entry in originals.entries)
            if (entry.value != null) entry.key: entry.value,
        });
        await _organizationBox?.put(
          'search:organization',
          previousOrganization.toJson(),
        );
        rethrow;
      }
    });
  }

  @override
  Future<void> restoreForProfile(
    String profileId,
    List<FollowingTopic> topics,
  ) {
    return _serialize(() async {
      if (topics.any(
        (topic) => topic.profileId != profileId,
      )) {
        throw ArgumentError.value(
          topics,
          'topics',
          'All restored topics must belong to the profile.',
        );
      }
      final existingKeys = _box.values
          .where((object) => object.profileId == profileId)
          .map((object) => object.id)
          .toList();
      await _box.deleteAll(existingKeys);
      await _box.putAll({
        for (final topic in topics) topic.id: _toObject(topic),
      });
      final storage = _organizationBox;
      if (storage != null) {
        final previousOverrides = storage.get('search:auto_update_overrides');
        final previousEstimates = storage.get('search:new_post_estimates');
        final overrides = <dynamic, dynamic>{
          if (previousOverrides is Map) ...previousOverrides,
        };
        final estimates = <dynamic, dynamic>{
          if (previousEstimates is Map) ...previousEstimates,
        };
        for (final id in [...existingKeys, ...topics.map((s) => s.id)]) {
          overrides.remove(id);
          estimates.remove(id);
        }
        for (final source in topics) {
          if (!source.autoUpdateEnabled) overrides[source.id] = false;
          if (source.newPostCountEstimate case final count?) {
            estimates[source.id] = {
              'count': count,
              'lowerBound': source.newPostCountIsLowerBound,
            };
          }
        }
        await storage.putAll({
          'search:auto_update_overrides': overrides,
          'search:new_post_estimates': estimates,
        });
      }
    });
  }

  Future<T> _read<T>(T Function() operation) async {
    await _mutationTail;
    return operation();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
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

  Iterable<FollowingTopic> _topics() {
    return _box.values
        .where((object) => isCanonicalProfileId(object.profileId))
        .map(_toTopic)
        .toList()
      ..sort(_compareSubscriptions);
  }

  TopicOrganization _organization() {
    final stored = switch (_organizationBox?.get('search:organization')) {
      final Map json => TopicOrganization.fromJson(json),
      _ => TopicOrganization(folders: const []),
    };
    final internalIds = _feedSourceIds();
    final topics = {
      for (final topic in _topics())
        if (!internalIds.contains(topic.id)) topic.id: topic,
    };
    final memberships = <String>{};
    final folders = [
      for (final folder in stored.folders)
        TopicFolder(
          id: folder.id,
          name: folder.name,
          feedEnabled: folder.feedEnabled,
          feedMaxPosts: folder.feedMaxPosts,
          parentId: folder.parentId,
          position: folder.position,
          searchIds: folder.searchIds.where(
            (id) => topics.containsKey(id) && memberships.add(id),
          ),
        ),
    ];
    final homeSearchIds = stored.homeSearchIds
        .where((id) => topics.containsKey(id) && memberships.add(id))
        .toList();
    final unlisted =
        topics.values.where((topic) => memberships.add(topic.id)).toList()
          ..sort((left, right) {
            final byCreatedAt = left.createdAt.compareTo(right.createdAt);
            return byCreatedAt != 0 ? byCreatedAt : left.id.compareTo(right.id);
          });
    return TopicOrganization(
      folders: folders,
      homeSearchIds: [...homeSearchIds, ...unlisted.map((search) => search.id)],
    );
  }

  TopicOrganization _removeOrganizationMemberships(
    TopicOrganization organization,
    Set<String> ids,
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
          searchIds: folder.searchIds.where((id) => !ids.contains(id)),
        ),
    ],
    homeSearchIds: organization.homeSearchIds.where((id) => !ids.contains(id)),
  );

  void _validateOrganizationMemberships(
    Iterable<String> ids,
    Set<String> memberships,
    Map<String, FollowingTopic> topics,
  ) {
    final internalIds = _feedSourceIds();
    for (final id in ids) {
      final topic = topics[id];
      if (!memberships.add(id) || topic == null || internalIds.contains(id)) {
        throw StateError('Invalid shared search membership');
      }
    }
  }

  Iterable<FollowingTopic> _topicsForProfile(String profileId) {
    final internalIds = _feedSourceIds();
    return _topics().where(
      (topic) =>
          topic.profileId == profileId && !internalIds.contains(topic.id),
    );
  }

  FollowingTopicHiveObject _requireObject(String id) {
    final object = _box.get(id.trim());
    if (object == null) {
      throw StateError('Followed topic ${id.trim()} does not exist.');
    }
    return object;
  }

  Future<void> _writeContiguousPositions(String profileId) async {
    final objects = <String, FollowingTopicHiveObject>{
      for (final (index, topic) in _topicsForProfile(
        profileId,
      ).indexed)
        topic.id: _toObject(topic.copyWithPosition(index)),
    };
    await _box.putAll(objects);
  }

  List<SearchPostPreview> _mergePreviews(
    List<SearchPostPreview> discovered,
    List<SearchPostPreview> current,
  ) {
    final byPostId = <int, SearchPostPreview>{};
    for (final preview in [...discovered, ...current]) {
      byPostId.putIfAbsent(preview.postId, () => preview);
    }
    final previews = byPostId.values.toList()..sort(_comparePreviews);
    return previews.take(4).toList();
  }

  int _compareSubscriptions(
    FollowingTopic left,
    FollowingTopic right,
  ) {
    final byProfile = left.profileId.compareTo(right.profileId);
    if (byProfile != 0) {
      return byProfile;
    }
    final byPosition = left.position.compareTo(right.position);
    return byPosition != 0 ? byPosition : left.id.compareTo(right.id);
  }

  int _comparePreviews(SearchPostPreview left, SearchPostPreview right) {
    return switch ((left.postCreatedAt, right.postCreatedAt)) {
      (final leftCreatedAt?, final rightCreatedAt?) =>
        rightCreatedAt.compareTo(leftCreatedAt) != 0
            ? rightCreatedAt.compareTo(leftCreatedAt)
            : right.postId.compareTo(left.postId),
      (null, null) => right.postId.compareTo(left.postId),
      (null, _) => 1,
      (_, null) => -1,
    };
  }

  FollowingTopic _toTopic(FollowingTopicHiveObject object) {
    final overrides = _organizationBox?.get('search:auto_update_overrides');
    final estimates = _organizationBox?.get('search:new_post_estimates');
    final estimate = estimates is Map ? estimates[object.id] : null;
    return FollowingTopic(
      autoUpdateEnabled: overrides is! Map || overrides[object.id] != false,
      newPostCountEstimate: switch (estimate) {
        final Map value => switch (value['count']) {
          final int count when count > 0 => count,
          _ => null,
        },
        _ => null,
      },
      newPostCountIsLowerBound:
          estimate is Map && estimate['lowerBound'] == true,
      id: object.id,
      profileId: object.profileId,
      query: object.query,
      queryStructure: SearchQueryStructure.tryParse(object.queryStructure),
      name: object.name,
      position: object.position,
      createdAt: object.createdAt,
      runtimeRevision: object.runtimeRevision,
      adaptiveState: AdaptiveRefreshState(
        interval: Duration(
          milliseconds: object.adaptiveIntervalMilliseconds.clamp(
            21600000,
            604800000,
          ),
        ),
        consecutiveEmptyAutomatic: object.emptyAutomaticStreak == 1 ? 1 : 0,
      ),
      lastMaterialEditAt: object.lastMaterialEditAt,
      previews: object.previews.take(4).map(_toPreview).toList(),
      recentPostIdentities: object.recentPostIdentities.reversed
          .take(50)
          .map(
            (identity) => RecentSearchPostIdentity(
              postId: identity.postId,
              postCreatedAt: identity.postCreatedAt,
            ),
          )
          .toList(),
      unreadCount: object.unreadCount,
      lastAttemptAt: object.lastAttemptAt,
      lastSuccessfulCheckAt: object.lastSuccessfulCheckAt,
      highestSeenPostId: object.highestSeenPostId,
      lastErrorKind: _toErrorKind(object.lastErrorKind),
    );
  }

  FollowingTopicHiveObject _toObject(FollowingTopic topic) {
    return FollowingTopicHiveObject(
      id: topic.id,
      profileId: topic.profileId,
      query: topic.query,
      queryStructure: topic.queryStructure?.toJson(),
      name: topic.name,
      position: topic.position,
      createdAt: topic.createdAt,
      runtimeRevision: topic.runtimeRevision,
      adaptiveIntervalMilliseconds: topic.adaptiveState.interval.inMilliseconds,
      emptyAutomaticStreak: topic.adaptiveState.consecutiveEmptyAutomatic,
      lastMaterialEditAt: topic.lastMaterialEditAt,
      lastAttemptAt: topic.lastAttemptAt,
      lastSuccessfulCheckAt: topic.lastSuccessfulCheckAt,
      highestSeenPostId: topic.highestSeenPostId,
      unreadCount: topic.unreadCount,
      lastErrorKind: topic.lastErrorKind?.name,
      previews: topic.previews.map(_toPreviewObject).toList(),
      recentPostIdentities: topic.recentPostIdentities
          .map(
            (identity) => RecentSearchPostHiveObject(
              postId: identity.postId,
              postCreatedAt: identity.postCreatedAt,
            ),
          )
          .toList(),
    );
  }

  SearchPostPreview _toPreview(SearchPostPreviewHiveObject object) {
    return SearchPostPreview(
      postId: object.postId,
      postCreatedAt: object.postCreatedAt,
      thumbnailUrl: object.thumbnailUrl,
      sampleUrl: object.sampleUrl,
      discoveredAt: object.discoveredAt,
    );
  }

  SearchPostPreviewHiveObject _toPreviewObject(SearchPostPreview preview) {
    return SearchPostPreviewHiveObject(
      postId: preview.postId,
      postCreatedAt: preview.postCreatedAt,
      thumbnailUrl: preview.thumbnailUrl,
      sampleUrl: preview.sampleUrl,
      discoveredAt: preview.discoveredAt,
    );
  }

  SearchRefreshErrorKind? _toErrorKind(String? name) {
    if (name == null) {
      return null;
    }
    for (final kind in SearchRefreshErrorKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return SearchRefreshErrorKind.other;
  }
}

extension on FollowingTopic {
  FollowingTopic copyWithName(String? name) {
    return FollowingTopic(
      id: id,
      profileId: profileId,
      query: query,
      queryStructure: queryStructure,
      name: name,
      position: position,
      createdAt: createdAt,
      runtimeRevision: runtimeRevision,
      adaptiveState: adaptiveState,
      lastMaterialEditAt: lastMaterialEditAt,
      previews: previews,
      recentPostIdentities: recentPostIdentities,
      unreadCount: unreadCount,
      lastAttemptAt: lastAttemptAt,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
      highestSeenPostId: highestSeenPostId,
      lastErrorKind: lastErrorKind,
    );
  }

  FollowingTopic copyWithPosition(int value) {
    return FollowingTopic(
      id: id,
      profileId: profileId,
      query: query,
      queryStructure: queryStructure,
      name: name,
      position: value,
      createdAt: createdAt,
      runtimeRevision: runtimeRevision,
      adaptiveState: adaptiveState,
      lastMaterialEditAt: lastMaterialEditAt,
      previews: previews,
      recentPostIdentities: recentPostIdentities,
      unreadCount: unreadCount,
      lastAttemptAt: lastAttemptAt,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
      highestSeenPostId: highestSeenPostId,
      lastErrorKind: lastErrorKind,
    );
  }

  FollowingTopic copyWithUnreadCount(int value) {
    return FollowingTopic(
      id: id,
      profileId: profileId,
      query: query,
      queryStructure: queryStructure,
      name: name,
      position: position,
      createdAt: createdAt,
      runtimeRevision: runtimeRevision,
      adaptiveState: adaptiveState,
      lastMaterialEditAt: lastMaterialEditAt,
      previews: previews,
      recentPostIdentities: recentPostIdentities,
      unreadCount: value,
      lastAttemptAt: lastAttemptAt,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
      highestSeenPostId: highestSeenPostId,
      lastErrorKind: lastErrorKind,
    );
  }
}
