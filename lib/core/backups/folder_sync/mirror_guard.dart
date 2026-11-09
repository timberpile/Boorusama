import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cache/misc_data_store.dart';

import '../../bookmarks/src/types/bookmark_group.dart';
import '../../search/following_topics/src/types/topic_organization.dart';

/// The shared write boundary consults this guard, including manual imports and
/// bulk deletion. Local naming and placement are intentionally not protected.
const folderSyncMetadataKey = 'collection_folder_sync_v1';

final collectionMirrorGuardProvider = Provider<CollectionMirrorGuard>((ref) {
  final guard = CollectionMirrorGuard();
  final encoded = ref.watch(miscDataStoreProvider).get(folderSyncMetadataKey);
  if (encoded != null) {
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    if (decoded['version'] != 1) {
      throw const FormatException('Unsupported local sync metadata');
    }
    final subscriptions = decoded['subscriptions'] as Map<String, dynamic>;
    guard.replaceFollowingBindings({
      for (final value in subscriptions.values)
        if (value['kind'] == 'following_topics') value['localId'] as String,
    });
    guard.replaceBindings({
      for (final value in subscriptions.values)
        if (value['kind'] == 'bookmarks') value['localId'] as String,
    });
  }
  return guard;
});

final class CollectionMirrorGuard {
  final _groupIds = <String>{};
  final _followingIds = <String>{};
  final _authority = Object();
  final _deletionAuthority = Object();

  Set<String> get groupIds => Set.unmodifiable(_groupIds);
  bool isReadOnly(String id) => _groupIds.contains(id);
  bool isFollowingReadOnly(String id) => _followingIds.contains(id);
  void replaceFollowingBindings(Iterable<String> ids) {
    _followingIds
      ..clear()
      ..addAll(ids);
  }

  void validateFollowingEdit(String id, {required bool definitionChanged}) {
    if (_granted(_authority) || !definitionChanged) return;
    if (_followingIds.contains(id)) throw const CollectionMirrorReadOnly();
  }

  void validateFollowingRemoval(Iterable<String> ids) {
    if (_granted(_authority) || _granted(_deletionAuthority)) {
      return;
    }
    if (ids.any(_followingIds.contains)) throw const CollectionMirrorReadOnly();
  }

  void validateFollowingOrganization(
    TopicOrganization before,
    TopicOrganization after,
  ) {
    if (_granted(_authority)) return;
    final next = {for (final folder in after.folders) folder.id: folder};
    for (final folder in before.folders) {
      if (!_followingIds.contains(folder.id)) continue;
      final current = next[folder.id];
      if (current == null) {
        validateFollowingRemoval([folder.id]);
      } else if (current.feedEnabled != folder.feedEnabled ||
          current.feedMaxPosts != folder.feedMaxPosts) {
        throw const CollectionMirrorReadOnly();
      }
    }
  }

  void replaceBindings(Iterable<String> ids) {
    _groupIds
      ..clear()
      ..addAll(ids);
  }

  bool _granted(Object key) => switch (Zone.current[key]) {
    _MirrorWriteGrant(active: true) => true,
    _ => false,
  };

  Future<T> _withGrant<T>(Object key, Future<T> Function() operation) {
    final grant = _MirrorWriteGrant();
    return runZoned(() async {
      try {
        return await operation();
      } finally {
        grant.active = false;
      }
    }, zoneValues: {key: grant});
  }

  Future<T> applyReceived<T>(Future<T> Function() operation) =>
      _withGrant(_authority, operation);

  /// Called only by the startup transaction after checking its local preimage
  /// digest; it cannot authorize an unvalidated incoming package.
  Future<void> recoverVerifiedLocalSnapshot(Future<void> Function() restore) =>
      _withGrant(_authority, restore);

  Future<T> deleteLocalSubtree<T>(Future<T> Function() operation) =>
      _withGrant(_deletionAuthority, operation);

  void validate({
    required Iterable<BookmarkGroup> currentGroups,
    Iterable<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},
    Set<int> removeIds = const {},
    bool confirmedSubtreeDeletion = false,
  }) {
    if (_granted(_authority)) return;
    final allowDeletion =
        confirmedSubtreeDeletion || _granted(_deletionAuthority);
    final existing = {for (final group in currentGroups) group.id: group};
    for (final group in groups) {
      if (!_groupIds.contains(group.id)) continue;
      final before = existing[group.id];
      if (before == null ||
          !const SetEquality<int>().equals(
            before.bookmarkIds,
            group.bookmarkIds,
          ) ||
          !const MapEquality<int, DateTime>().equals(
            before.addedAt,
            group.addedAt,
          )) {
        throw const CollectionMirrorReadOnly();
      }
    }
    for (final id in _groupIds) {
      if (removeGroupIds.contains(id)) {
        if (!allowDeletion) throw const CollectionMirrorReadOnly();
      } else if (existing[id]?.bookmarkIds.intersection(removeIds).isNotEmpty ??
          false) {
        throw const CollectionMirrorReadOnly();
      }
    }
  }
}

final class CollectionMirrorReadOnly implements Exception {
  const CollectionMirrorReadOnly();
}

final class _MirrorWriteGrant {
  bool active = true;
}
