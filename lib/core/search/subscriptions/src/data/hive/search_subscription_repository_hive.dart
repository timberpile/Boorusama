// Dart imports:
import 'dart:async';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../types/search_post_preview.dart';
import '../../types/search_refresh.dart';
import '../../types/search_following_feed.dart';
import '../../types/search_organization.dart';
import '../../types/search_subscription.dart';
import '../../types/search_subscription_repository.dart';
import 'recent_search_post_hive_object.dart';
import 'search_post_preview_hive_object.dart';
import 'search_subscription_hive_object.dart';

class HiveSearchSubscriptionRepository implements SearchSubscriptionRepository {
  HiveSearchSubscriptionRepository({
    required Box<SearchSubscriptionHiveObject> box,
    Box<dynamic>? organizationBox,
    Uuid uuid = const Uuid(),
  }) : _organizationBox = organizationBox,
       _box = box,
       _uuid = uuid;

  final Box<SearchSubscriptionHiveObject> _box;
  final Uuid _uuid;
  final Box<dynamic>? _organizationBox;
  Future<void> _mutationTail = Future.value();

  List<SearchFollowingFeed> _feeds() => [
    for (final value in _organizationBox?.values ?? const [])
      if (value case final Map json
          when json['id'] is String &&
              json['profileId'] is int &&
              json['name'] is String)
        SearchFollowingFeed.fromJson({
          ...json,
          if (json['sourceIds'] is! List)
            'sourceIds': [
              for (final search in _box.values)
                if (search.feedId == json['id']) search.id,
            ],
        }),
  ];

  Set<String> _feedSourceIds() => {
    for (final feed in _feeds()) ...feed.sourceIds,
  };

  @override
  Future<List<SearchFollowingFeed>> getFeeds() => _serialize(() async {
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
  Future<SearchFollowingFeed> saveFeed({
    required int profileId,
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
        normalized.length > followingFeedSourceLimit) {
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
    final all = _subscriptions().toList();
    final internalIds = _feedSourceIds();
    final internalByQuery = <String, SearchSubscription>{
      for (final search in all)
        if (internalIds.contains(search.id) && search.profileId == profileId)
          normalizeSearchIdentity(search.query): search,
    };
    final retained = <SearchSubscription>[];
    for (final (position, query) in normalized.indexed) {
      final existing = internalByQuery[query];
      retained.add(
        existing ??
            SearchSubscription.create(
              id: _uuid.v4(),
              profileId: profileId,
              query: query,
              name: null,
              position: position,
              createdAt: DateTime.now().toUtc(),
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
    final feed = SearchFollowingFeed(
      id: feedId,
      profileId: profileId,
      name: name.trim(),
      position:
          previous?.position ??
          feeds.where((f) => f.profileId == profileId).length,
      sourceIds: retained.map((source) => source.id).toList(),
      posts: removedIds.isNotEmpty ? const [] : previous?.posts ?? const [],
    );
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
    final referencedElsewhere = {
      for (final item in feeds)
        if (item.id != id) ...item.sourceIds,
    };
    final orphanIds = feed.sourceIds.toSet().difference(referencedElsewhere);
    final sources = {
      for (final source in _subscriptions())
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
  Future<void> restoreFeeds(int profileId, List<SearchFollowingFeed> feeds) =>
      _serialize(() async {
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
  Future<SearchOrganization> getOrganization() => _read(_organization);

  @override
  Future<void> replaceOrganization(SearchOrganization organization) =>
      _serialize(() async {
        final storage = _organizationBox;
        if (storage == null) {
          throw StateError('Organization storage unavailable');
        }
        final folderIds = <String>{};
        final folderNames = <String>{};
        final memberships = <String>{};
        final subscriptions = {
          for (final subscription in _subscriptions())
            subscription.id: subscription,
        };

        for (final folder in organization.folders) {
          if (!folderIds.add(folder.id) ||
              !folderNames.add(folder.name.toLowerCase())) {
            throw StateError('Duplicate shared search folder');
          }
          _validateOrganizationMemberships(
            folder.searchIds,
            memberships,
            subscriptions,
          );
        }
        _validateOrganizationMemberships(
          organization.homeSearchIds,
          memberships,
          subscriptions,
        );
        await storage.put('search:organization', organization.toJson());
      });

  @override
  Future<void> deleteSharedFolderAndPins(String folderId) => _serialize(
    () async {
      final storage = _organizationBox;
      if (storage == null) throw StateError('Organization storage unavailable');
      final previousOrganization = _organization();
      final folder = previousOrganization.folders
          .where((folder) => folder.id == folderId)
          .firstOrNull;
      if (folder == null) return;
      final previousPins = {
        for (final id in folder.searchIds) id: ?_box.get(id),
      };
      final nextOrganization = SearchOrganization(
        folders: previousOrganization.folders.where(
          (item) => item.id != folderId,
        ),
        homeSearchIds: previousOrganization.homeSearchIds,
      );
      try {
        await _box.deleteAll(previousPins.keys);
        await storage.put('search:organization', nextOrganization.toJson());
      } catch (_) {
        await _box.putAll(previousPins);
        await storage.put('search:organization', previousOrganization.toJson());
        rethrow;
      }
    },
  );

  @override
  Future<List<SearchSubscription>> getAll() {
    return _read(() => _subscriptions().toList());
  }

  @override
  Future<SearchSubscription?> getById(String id) {
    return _read(() {
      final object = _box.get(id.trim());
      return object == null ? null : _toSubscription(object);
    });
  }

  @override
  Future<SearchSubscription?> findByQuery(int profileId, String query) {
    return _read(() {
      final normalizedQuery = normalizeSearchIdentity(query);
      final internalIds = _feedSourceIds();
      for (final subscription in _subscriptions()) {
        if (subscription.profileId == profileId &&
            !internalIds.contains(subscription.id) &&
            normalizeSearchIdentity(subscription.query) == normalizedQuery) {
          return subscription;
        }
      }
      return null;
    });
  }

  @override
  Future<SearchSubscription> create({
    required int profileId,
    required String query,
    required String? name,
    String? id,
    DateTime? createdAt,
  }) {
    return _serialize(() async {
      final normalizedQuery = normalizeSearchIdentity(query);
      if (normalizedQuery.isEmpty) {
        throw const FormatException('Pinned search queries cannot be empty.');
      }
      final subscriptions = _subscriptions().toList();
      final internalIds = _feedSourceIds();
      if (subscriptions.any(
        (subscription) =>
            subscription.profileId == profileId &&
            !internalIds.contains(subscription.id) &&
            normalizeSearchIdentity(subscription.query) == normalizedQuery,
      )) {
        throw StateError(
          'Pinned search query already exists for this profile.',
        );
      }

      final subscriptionId = (id ?? _uuid.v4()).trim().toLowerCase();
      if (subscriptionId.isEmpty) {
        throw const FormatException('Pinned search IDs cannot be empty.');
      }
      if (_box.containsKey(subscriptionId)) {
        throw StateError('Pinned search $subscriptionId already exists.');
      }
      final subscription = SearchSubscription.create(
        id: subscriptionId,
        profileId: profileId,
        query: query,
        name: name,
        position: subscriptions
            .where(
              (subscription) =>
                  subscription.profileId == profileId &&
                  !internalIds.contains(subscription.id),
            )
            .fold(
              0,
              (next, item) => item.position >= next ? item.position + 1 : next,
            ),
        createdAt: createdAt ?? DateTime.now().toUtc(),
      );
      final object = _toObject(subscription);
      await _box.put(subscription.id, object);
      return _toSubscription(object);
    });
  }

  @override
  Future<SearchSubscription> rename(String id, String? name) {
    return _serialize(() async {
      final current = _requireObject(id);
      final updated = _toSubscription(current).copyWithName(name);
      final object = _toObject(updated);
      await _box.put(object.id, object);
      return _toSubscription(object);
    });
  }

  @override
  Future<List<SearchSubscription>> reorder(
    int profileId,
    int oldIndex,
    int newIndex,
  ) {
    return _serialize(() async {
      final subscriptions = _subscriptionsForProfile(profileId).toList();
      if (oldIndex < 0 || oldIndex >= subscriptions.length) {
        throw RangeError.index(oldIndex, subscriptions, 'oldIndex');
      }
      if (newIndex < 0 || newIndex >= subscriptions.length) {
        throw RangeError.index(newIndex, subscriptions, 'newIndex');
      }
      final moved = subscriptions.removeAt(oldIndex);
      subscriptions.insert(newIndex, moved);
      final objects = <String, SearchSubscriptionHiveObject>{
        for (var index = 0; index < subscriptions.length; index++)
          subscriptions[index].id: _toObject(
            subscriptions[index].copyWithPosition(index),
          ),
      };
      await _box.putAll(objects);
      return objects.values.map(_toSubscription).toList();
    });
  }

  @override
  Future<SearchSubscription?> markRead(String id) {
    return _serialize(() async {
      final current = _box.get(id.trim());
      if (current == null) {
        return null;
      }
      final updated = _toSubscription(current).copyWithUnreadCount(0);
      final object = _toObject(updated);
      await _box.put(object.id, object);
      return _toSubscription(object);
    });
  }

  @override
  Future<SearchSubscription?> commitRefresh(SearchRefreshCommit commit) {
    return _serialize(() async {
      final currentObject = _box.get(commit.subscriptionId.trim());
      if (currentObject == null) {
        return null;
      }
      final current = _toSubscription(currentObject);
      if (current.createdAt != commit.expectedCreatedAt ||
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

      final previews = _mergePreviews(commit.discoveredPosts, const []);
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
      final updated = SearchSubscription(
        id: current.id,
        profileId: current.profileId,
        query: current.query,
        name: current.name,
        position: current.position,
        createdAt: current.createdAt,
        previews: previews,
        recentPostIdentities: recentPostIdentities.take(50).toList(),
        unreadCount:
            !commit.baseline &&
                (current.hasNewPosts ||
                    newlyDiscovered.any(
                      (preview) => switch ((
                        preview.postCreatedAt,
                        commit.expectedCheckpoint,
                      )) {
                        (
                          final DateTime uploadedAt,
                          final DateTime checkpoint,
                        ) =>
                          uploadedAt.isAfter(checkpoint),
                        _ => false,
                      },
                    ))
            ? 1
            : 0,
        lastAttemptAt: commit.startedAt,
        lastSuccessfulCheckAt: commit.startedAt,
      );
      final object = _toObject(updated);
      final referencingFeeds = _feeds()
          .where((feed) => feed.sourceIds.contains(current.id))
          .toList();
      final previousFeeds = <String, Object?>{
        for (final feed in referencingFeeds)
          feed.id: _organizationBox?.get('feed:${feed.id}'),
      };
      for (final feed in referencingFeeds) {
        await _organizationBox?.put(
          'feed:${feed.id}',
          feed.merge(commit.feedPosts).toJson(),
        );
      }
      try {
        await _box.put(object.id, object);
      } catch (_) {
        for (final entry in previousFeeds.entries) {
          if (entry.value != null) {
            await _organizationBox?.put('feed:${entry.key}', entry.value);
          }
        }
        rethrow;
      }
      return _toSubscription(object);
    });
  }

  @override
  Future<SearchSubscription?> recordRefreshFailure(
    String id, {
    required DateTime expectedCreatedAt,
    required DateTime attemptedAt,
    required SearchRefreshErrorKind kind,
  }) {
    return _serialize(() async {
      final current = _box.get(id.trim());
      if (current == null || current.createdAt != expectedCreatedAt) {
        return null;
      }
      final subscription = _toSubscription(current);
      final updated = SearchSubscription(
        id: subscription.id,
        profileId: subscription.profileId,
        query: subscription.query,
        name: subscription.name,
        position: subscription.position,
        createdAt: subscription.createdAt,
        previews: subscription.previews,
        recentPostIdentities: subscription.recentPostIdentities,
        unreadCount: subscription.unreadCount,
        lastAttemptAt: attemptedAt,
        lastSuccessfulCheckAt: subscription.lastSuccessfulCheckAt,
        lastErrorKind: kind,
      );
      final object = _toObject(updated);
      await _box.put(object.id, object);
      return _toSubscription(object);
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
      final previousPins = {
        for (final subscription in _subscriptions())
          if (subscription.profileId == current.profileId)
            subscription.id: _toObject(subscription),
      };
      final nextOrganization = _removeOrganizationMemberships(
        previousOrganization,
        {current.id},
      );
      try {
        await _organizationBox?.put(
          'search:organization',
          nextOrganization.toJson(),
        );
        await _box.delete(current.id);
        await _writeContiguousPositions(current.profileId);
      } catch (_) {
        await _box.putAll(previousPins);
        await _organizationBox?.put(
          'search:organization',
          previousOrganization.toJson(),
        );
        rethrow;
      }
    });
  }

  @override
  Future<void> deleteForProfile(int profileId) {
    return _serialize(() async {
      final keys = _box.values
          .where((object) => object.profileId == profileId)
          .map((object) => object.id)
          .toList();
      final previousPins = {
        for (final id in keys) id: ?_box.get(id),
      };
      final previousOrganization = _organization();
      final nextOrganization = _removeOrganizationMemberships(
        previousOrganization,
        keys.toSet(),
      );
      final previous = _organizationBox?.get(profileId);
      final feeds = _feeds().where((f) => f.profileId == profileId).toList();
      try {
        await _organizationBox?.deleteAll(feeds.map((f) => 'feed:${f.id}'));
        await _organizationBox?.delete(profileId);
        await _organizationBox?.put(
          'search:organization',
          nextOrganization.toJson(),
        );
        await _box.deleteAll(keys);
      } catch (_) {
        await _box.putAll(previousPins);
        if (previous != null) await _organizationBox?.put(profileId, previous);
        await _organizationBox?.putAll({
          for (final f in feeds) 'feed:${f.id}': f.toJson(),
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
    int profileId,
    List<SearchSubscription> subscriptions,
  ) {
    return _serialize(() async {
      if (subscriptions.any(
        (subscription) => subscription.profileId != profileId,
      )) {
        throw ArgumentError.value(
          subscriptions,
          'subscriptions',
          'All restored subscriptions must belong to the profile.',
        );
      }
      final existingKeys = _box.values
          .where((object) => object.profileId == profileId)
          .map((object) => object.id)
          .toList();
      await _box.deleteAll(existingKeys);
      await _box.putAll({
        for (final subscription in subscriptions)
          subscription.id: _toObject(subscription),
      });
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

  Iterable<SearchSubscription> _subscriptions() {
    return _box.values.map(_toSubscription).toList()
      ..sort(_compareSubscriptions);
  }

  SearchOrganization _organization() {
    final stored = switch (_organizationBox?.get('search:organization')) {
      final Map json => SearchOrganization.fromJson(json),
      _ => SearchOrganization(folders: const [], homeSearchIds: const []),
    };
    final internalIds = _feedSourceIds();
    final subscriptions = {
      for (final subscription in _subscriptions())
        if (!internalIds.contains(subscription.id))
          subscription.id: subscription,
    };
    final memberships = <String>{};
    final folders = [
      for (final folder in stored.folders)
        SharedSearchFolder(
          id: folder.id,
          name: folder.name,
          searchIds: folder.searchIds.where(
            (id) => subscriptions.containsKey(id) && memberships.add(id),
          ),
        ),
    ];
    final homeSearchIds = stored.homeSearchIds
        .where((id) => subscriptions.containsKey(id) && memberships.add(id))
        .toList();
    final unlisted =
        subscriptions.values
            .where((subscription) => memberships.add(subscription.id))
            .toList()
          ..sort((left, right) {
            final byCreatedAt = left.createdAt.compareTo(right.createdAt);
            return byCreatedAt != 0 ? byCreatedAt : left.id.compareTo(right.id);
          });
    return SearchOrganization(
      folders: folders,
      homeSearchIds: [...homeSearchIds, ...unlisted.map((search) => search.id)],
    );
  }

  SearchOrganization _removeOrganizationMemberships(
    SearchOrganization organization,
    Set<String> ids,
  ) => SearchOrganization(
    folders: [
      for (final folder in organization.folders)
        SharedSearchFolder(
          id: folder.id,
          name: folder.name,
          searchIds: folder.searchIds.where((id) => !ids.contains(id)),
        ),
    ],
    homeSearchIds: organization.homeSearchIds.where((id) => !ids.contains(id)),
  );

  void _validateOrganizationMemberships(
    Iterable<String> ids,
    Set<String> memberships,
    Map<String, SearchSubscription> subscriptions,
  ) {
    final internalIds = _feedSourceIds();
    for (final id in ids) {
      final subscription = subscriptions[id];
      if (!memberships.add(id) ||
          subscription == null ||
          internalIds.contains(id)) {
        throw StateError('Invalid shared search membership');
      }
    }
  }

  Iterable<SearchSubscription> _subscriptionsForProfile(int profileId) {
    final internalIds = _feedSourceIds();
    return _subscriptions().where(
      (subscription) =>
          subscription.profileId == profileId &&
          !internalIds.contains(subscription.id),
    );
  }

  SearchSubscriptionHiveObject _requireObject(String id) {
    final object = _box.get(id.trim());
    if (object == null) {
      throw StateError('Pinned search ${id.trim()} does not exist.');
    }
    return object;
  }

  Future<void> _writeContiguousPositions(int profileId) async {
    final objects = <String, SearchSubscriptionHiveObject>{
      for (final (index, subscription) in _subscriptionsForProfile(
        profileId,
      ).indexed)
        subscription.id: _toObject(subscription.copyWithPosition(index)),
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
    SearchSubscription left,
    SearchSubscription right,
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

  SearchSubscription _toSubscription(SearchSubscriptionHiveObject object) {
    return SearchSubscription(
      id: object.id,
      profileId: object.profileId,
      query: object.query,
      name: object.name,
      position: object.position,
      createdAt: object.createdAt,
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
      lastErrorKind: _toErrorKind(object.lastErrorKind),
    );
  }

  SearchSubscriptionHiveObject _toObject(SearchSubscription subscription) {
    return SearchSubscriptionHiveObject(
      id: subscription.id,
      profileId: subscription.profileId,
      query: subscription.query,
      name: subscription.name,
      position: subscription.position,
      createdAt: subscription.createdAt,
      lastAttemptAt: subscription.lastAttemptAt,
      lastSuccessfulCheckAt: subscription.lastSuccessfulCheckAt,
      unreadCount: subscription.unreadCount,
      lastErrorKind: subscription.lastErrorKind?.name,
      previews: subscription.previews.map(_toPreviewObject).toList(),
      recentPostIdentities: subscription.recentPostIdentities
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

extension on SearchSubscription {
  SearchSubscription copyWithName(String? name) {
    return SearchSubscription(
      id: id,
      profileId: profileId,
      query: query,
      name: name,
      position: position,
      createdAt: createdAt,
      previews: previews,
      recentPostIdentities: recentPostIdentities,
      unreadCount: unreadCount,
      lastAttemptAt: lastAttemptAt,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
      lastErrorKind: lastErrorKind,
    );
  }

  SearchSubscription copyWithPosition(int value) {
    return SearchSubscription(
      id: id,
      profileId: profileId,
      query: query,
      name: name,
      position: value,
      createdAt: createdAt,
      previews: previews,
      recentPostIdentities: recentPostIdentities,
      unreadCount: unreadCount,
      lastAttemptAt: lastAttemptAt,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
      lastErrorKind: lastErrorKind,
    );
  }

  SearchSubscription copyWithUnreadCount(int value) {
    return SearchSubscription(
      id: id,
      profileId: profileId,
      query: query,
      name: name,
      position: position,
      createdAt: createdAt,
      previews: previews,
      recentPostIdentities: recentPostIdentities,
      unreadCount: value,
      lastAttemptAt: lastAttemptAt,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
      lastErrorKind: lastErrorKind,
    );
  }
}
