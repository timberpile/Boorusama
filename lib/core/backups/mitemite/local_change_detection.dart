import 'package:collection/collection.dart';

import '../../bookmarks/src/types/bookmark.dart';
import '../../bookmarks/src/types/bookmark_group.dart';
import '../../bookmarks/src/types/bookmark_library_state.dart';
import '../../search/following_topics/src/providers/following_topics_notifier.dart';

/// Domain ownership, not a service-wide "applying" flag, separates outgoing
/// changes from local read acknowledgements and received-only updates. A local
/// edit concurrent with receive must still schedule a follow-up publication.
bool hasLocalSyncChanges(
  BookmarkLibraryState before,
  BookmarkLibraryState after,
) {
  if (identical(before, after) ||
      (identical(before.groups, after.groups) &&
          identical(before.records, after.records) &&
          before.mirrors.owners.length == after.mirrors.owners.length &&
          before.mirrors.owners.keys.every(after.mirrors.owners.containsKey))) {
    return false;
  }
  if (!const SetEquality<String>().equals(
    before.localGroupIds,
    after.localGroupIds,
  )) {
    return true;
  }
  for (final id in before.localGroupIds) {
    if (!_sameGroup(before.groupsById[id]!, after.groupsById[id]!)) return true;
  }
  return !const ListEquality<Bookmark>().equals(
    before.localRecords,
    after.localRecords,
  );
}

bool _sameGroup(BookmarkGroup a, BookmarkGroup b) =>
    identical(a, b) ||
    a.name == b.name &&
        a.parentGroupId == b.parentGroupId &&
        a.folderId == b.folderId &&
        a.position == b.position &&
        const SetEquality<int>().equals(a.bookmarkIds, b.bookmarkIds) &&
        const MapEquality<int, DateTime>().equals(a.addedAt, b.addedAt);

bool hasLocalFollowingSyncChanges(
  FollowingTopicsState before,
  FollowingTopicsState after,
) {
  Object definitions(FollowingTopicsState state) => [
    for (final t in state.topics)
      if (!state.mirrors.isReceived(t.id))
        [t.id, t.profileId, t.name, t.query, t.queryStructure],
    for (final f in state.organization.folders)
      if (!state.mirrors.isReceived(f.id))
        [f.id, f.name, f.parentId, f.position, f.feedEnabled, f.feedMaxPosts],
    for (final p in state.organization.placements)
      if (!state.mirrors.isReceived(p.itemId))
        [p.itemId, p.folderId, p.position],
  ];
  return !const DeepCollectionEquality().equals(
    definitions(before),
    definitions(after),
  );
}
