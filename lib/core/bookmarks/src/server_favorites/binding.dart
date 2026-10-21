import '../types/bookmark_group.dart';
import 'target_settings.dart';

/// A shared target is already bound and must never be cleared by another profile.
List<BookmarkGroup> serverFavoriteGroupsToClear(
  ServerFavoriteSettings current,
  ServerFavoriteSettings updated,
  Iterable<BookmarkGroup> groups,
) {
  final newlyBound = updated.assignedGroupIds.difference(
    current.assignedGroupIds,
  );
  return [
    for (final group in groups)
      if (newlyBound.contains(group.id) && group.bookmarkIds.isNotEmpty) group,
  ];
}
