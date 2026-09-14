import '../types/bookmark.dart';
import 'bookmark_convert.dart';

Set<BookmarkUniqueId> selectedBookmarkIdentities(
  List<BookmarkPost> posts,
  Set<int> selectedIndices,
) => {
  for (final index in selectedIndices)
    if (index >= 0 && index < posts.length) posts[index].bookmark.uniqueId,
};

List<int> bookmarkSelectionIndices(
  List<BookmarkPost> posts,
  Set<BookmarkUniqueId> identities,
) => [
  for (var index = 0; index < posts.length; index++)
    if (identities.contains(posts[index].bookmark.uniqueId)) index,
];
