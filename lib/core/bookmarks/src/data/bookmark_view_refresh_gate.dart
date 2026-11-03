import 'package:collection/collection.dart';

import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';
import '../types/pool_bookmark.dart';

/// Snapshot identity is preserved by normal mutations. Group-only metadata
/// changes must not refilter/resort the entire post list. Membership badges
/// subscribe independently and do not require a grid refresh.
bool bookmarkViewContentsChanged(
  BookmarkLibraryState? before,
  BookmarkLibraryState? after,
  BookmarkView view,
) {
  if (before == null || after == null) return true;
  if (identical(before, after)) return false;
  if (!identical(before.pools, after.pools)) {
    Iterable<CollectionBookmark> visible(BookmarkLibraryState state) =>
        view.kind == BookmarkViewKind.all
        ? state.pools
        : state.pools.where((p) => p.groupIds.contains(view.groupId));
    if (!const IterableEquality<CollectionBookmark>().equals(
      visible(before),
      visible(after),
    ))
      return true;
  }
  if (view.kind == BookmarkViewKind.all) {
    if (!identical(before.items, after.items)) return true;
    if (identical(before.groups, after.groups)) return false;
    for (final id in {...before.groupsById.keys, ...after.groupsById.keys}) {
      final previous = before.groupsById[id];
      final next = after.groupsById[id];
      if (!const SetEquality<int>().equals(
            previous?.bookmarkIds ?? const {},
            next?.bookmarkIds ?? const {},
          ) ||
          !const MapEquality<int, DateTime>().equals(
            previous?.addedAt ?? const {},
            next?.addedAt ?? const {},
          )) {
        return true;
      }
    }
    return false;
  }
  final previousMembers =
      before.groupsById[view.groupId]?.bookmarkIds ?? const <int>{};
  final nextMembers =
      after.groupsById[view.groupId]?.bookmarkIds ?? const <int>{};
  if (!const SetEquality<int>().equals(previousMembers, nextMembers))
    return true;
  if (!const MapEquality<int, DateTime>().equals(
    before.groupsById[view.groupId]?.addedAt,
    after.groupsById[view.groupId]?.addedAt,
  ))
    return true;
  if (identical(before.items, after.items)) return false;
  return nextMembers.any(
    (id) => !identical(before.bookmarksById[id], after.bookmarksById[id]),
  );
}

class BookmarkViewRefreshGate {
  var _detailsVisible = false;
  var _refreshPending = false;

  bool onLibraryChanged() {
    if (!_detailsVisible) return true;

    _refreshPending = true;
    return false;
  }

  bool onDetailsVisibilityChanged(bool visible) {
    _detailsVisible = visible;
    if (visible || !_refreshPending) return false;

    _refreshPending = false;
    return true;
  }
}
