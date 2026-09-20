// Dart imports:
import 'dart:async';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import '../../types/search_post_preview.dart';
import '../../types/search_refresh.dart';
import '../../types/search_folder.dart';
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
      if (value case final Map json) SearchFollowingFeed.fromJson(json),
  ];

  @override
  Future<List<SearchFollowingFeed>> getFeeds() => _read(_feeds);

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
        .where((q) => q.isNotEmpty)
        .toSet()
        .toList();
    if (name.trim().isEmpty ||
        normalized.isEmpty ||
        normalized.length > followingFeedSourceLimit) {
      throw const FormatException('Invalid feed definition');
    }
    final previous = id == null
        ? null
        : _feeds().where((f) => f.id == id).firstOrNull;
    if (previous != null && previous.profileId != profileId) {
      throw StateError('Feed ownership mismatch');
    }
    final feedId = previous?.id ?? id ?? _uuid.v4();
    final owned = _subscriptions().where((s) => s.feedId == feedId).toList();
    final retained = <SearchSubscription>[];
    for (final (position, query) in normalized.indexed) {
      final existing = owned
          .where((s) => normalizeSearchIdentity(s.query) == query)
          .firstOrNull;
      retained.add(
        existing ??
            SearchSubscription.create(
              id: _uuid.v4(),
              profileId: profileId,
              query: query,
              name: null,
              position: position,
              createdAt: DateTime.now().toUtc(),
              feedId: feedId,
            ),
      );
    }
    final changed = owned
        .map((s) => normalizeSearchIdentity(s.query))
        .toSet()
        .difference(normalized.toSet())
        .isNotEmpty;
    final feed = SearchFollowingFeed(
      id: feedId,
      profileId: profileId,
      name: name.trim(),
      position:
          previous?.position ??
          _feeds().where((f) => f.profileId == profileId).length,
      posts: changed ? const [] : previous?.posts ?? const [],
    );
    await storage.put('feed:$feedId', feed.toJson());
    try {
      await _box.putAll({for (final s in retained) s.id: _toObject(s)});
      await _box.deleteAll(
        owned.where((s) => !retained.any((r) => r.id == s.id)).map((s) => s.id),
      );
    } catch (_) {
      await _box.deleteAll(
        retained.where((s) => !owned.any((o) => o.id == s.id)).map((s) => s.id),
      );
      await _box.putAll({for (final s in owned) s.id: _toObject(s)});
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
    final feed = _feeds().where((f) => f.id == id).firstOrNull;
    if (feed == null) return;
    final sources = _subscriptions().where((s) => s.feedId == id).toList();
    await _organizationBox?.delete('feed:$id');
    try {
      await _box.deleteAll(sources.map((s) => s.id));
    } catch (_) {
      await _organizationBox?.put('feed:$id', feed.toJson());
      await _box.putAll({for (final s in sources) s.id: _toObject(s)});
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
  Future<List<SearchFolder>> getFolders() => _read(
    () => [
      for (final rows in _organizationBox?.values ?? const [])
        if (rows case final List values)
          for (final row in values)
            if (row case final Map json) SearchFolder.fromJson(json),
    ],
  );

  @override
  Future<void> replaceFolders(int profileId, List<SearchFolder> folders) =>
      _serialize(() async {
        final box = _organizationBox;
        if (box == null) throw StateError('Folder storage unavailable');
        final ids = <String>{};
        final memberships = <String>{};
        final names = <String>{};
        for (final folder in folders) {
          if (folder.profileId != profileId ||
              !ids.add(folder.id) ||
              !names.add(folder.name.toLowerCase())) {
            throw StateError('Invalid folder ownership or duplicate folder');
          }
          for (final id in folder.searchIds) {
            if (!memberships.add(id) ||
                _box.get(id)?.profileId != profileId ||
                _box.get(id)?.feedId != null) {
              throw StateError('Invalid search membership');
            }
          }
        }
        await box.put(
          profileId,
          folders.map((folder) => folder.toJson()).toList(),
        );
      });

  @override
  Future<SearchOrganization> getOrganization() => _read(_organization);

  @override
  Future<void> replaceOrganization(SearchOrganization organization) =>
      _serialize(() async {
        final storage = _organizationBox;
        if (storage == null)
          throw StateError('Organization storage unavailable');
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
      for (final subscription in _subscriptions()) {
        if (subscription.profileId == profileId &&
            subscription.feedId == null &&
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
      if (subscriptions.any(
        (subscription) =>
            subscription.profileId == profileId &&
            subscription.feedId == null &&
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
                  subscription.feedId == null,
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
        feedId: current.feedId,
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
      final previousFeed = current.feedId == null
          ? null
          : _organizationBox?.get('feed:${current.feedId}');
      if (previousFeed case final Map json) {
        final feed = SearchFollowingFeed.fromJson(json);
        await _organizationBox?.put(
          'feed:${feed.id}',
          feed.merge(commit.feedPosts).toJson(),
        );
      }
      try {
        await _box.put(object.id, object);
      } catch (_) {
        if (previousFeed != null) {
          await _organizationBox?.put('feed:${current.feedId}', previousFeed);
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
        feedId: subscription.feedId,
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
      final rows = _organizationBox?.get(current.profileId);
      if (rows case final List values) {
        final folders = [
          for (final row in values)
            if (row case final Map json) SearchFolder.fromJson(json),
        ];
        await _organizationBox?.put(current.profileId, [
          for (final folder in folders)
            folder
                .copyWith(
                  searchIds: folder.searchIds.where((id) => id != current.id),
                )
                .toJson(),
        ]);
      }
      try {
        await _box.delete(current.id);
      } catch (_) {
        if (rows != null) await _organizationBox?.put(current.profileId, rows);
        rethrow;
      }
      await _writeContiguousPositions(current.profileId);
    });
  }

  @override
  Future<void> deleteForProfile(int profileId) {
    return _serialize(() async {
      final keys = _box.values
          .where((object) => object.profileId == profileId)
          .map((object) => object.id)
          .toList();
      final previous = _organizationBox?.get(profileId);
      final feeds = _feeds().where((f) => f.profileId == profileId).toList();
      await _organizationBox?.deleteAll(feeds.map((f) => 'feed:${f.id}'));
      await _organizationBox?.delete(profileId);
      try {
        await _box.deleteAll(keys);
      } catch (_) {
        if (previous != null) await _organizationBox?.put(profileId, previous);
        await _organizationBox?.putAll({
          for (final f in feeds) 'feed:${f.id}': f.toJson(),
        });
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
    final subscriptions = {
      for (final subscription in _subscriptions())
        if (subscription.feedId == null) subscription.id: subscription,
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

  void _validateOrganizationMemberships(
    Iterable<String> ids,
    Set<String> memberships,
    Map<String, SearchSubscription> subscriptions,
  ) {
    for (final id in ids) {
      final subscription = subscriptions[id];
      if (!memberships.add(id) ||
          subscription == null ||
          subscription.feedId != null) {
        throw StateError('Invalid shared search membership');
      }
    }
  }

  Iterable<SearchSubscription> _subscriptionsForProfile(int profileId) {
    return _subscriptions().where(
      (subscription) =>
          subscription.profileId == profileId && subscription.feedId == null,
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
      feedId: object.feedId,
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
      feedId: subscription.feedId,
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
      feedId: feedId,
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
      feedId: feedId,
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
      feedId: feedId,
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
