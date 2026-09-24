import '../types/bookmark.dart';
import '../../../posts/post/types.dart';
import 'bookmark_convert.dart';

Set<BookmarkUniqueId> selectedBookmarkIdentities(
  List<Post> posts,
  Set<int> selectedIndices,
) => {
  for (final index in selectedIndices)
    if (index >= 0 && index < posts.length)
      bookmarkIdentityForPost(posts[index], -1),
};

List<int> bookmarkSelectionIndices(
  List<Post> posts,
  Set<BookmarkUniqueId> identities,
) => [
  for (var index = 0; index < posts.length; index++)
    if (identities.contains(bookmarkIdentityForPost(posts[index], -1))) index,
];
