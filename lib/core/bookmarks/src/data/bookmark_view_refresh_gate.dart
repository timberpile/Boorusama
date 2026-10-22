import 'package:collection/collection.dart';

import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';

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
  if (view.kind == BookmarkViewKind.all) {
    return !identical(before.items, after.items);
  }
  final previousMembers =
      before.groupsById[view.groupId]?.bookmarkIds ?? const <int>{};
  final nextMembers =
      after.groupsById[view.groupId]?.bookmarkIds ?? const <int>{};
  if (!const SetEquality<int>().equals(previousMembers, nextMembers))
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
