import '../types/bookmark.dart';
import '../../../posts/post/types.dart';

Set<BookmarkUniqueId> selectedBookmarkIdentities(
  List<Post> posts,
  Set<int> selectedIndices,
) => {
  for (final index in selectedIndices)
    if (index >= 0 && index < posts.length)
      ?BookmarkIdentity.tryFromPost(posts[index]),
};

List<int> bookmarkSelectionIndices(
  List<Post> posts,
  Set<BookmarkUniqueId> identities,
) => [
  for (var index = 0; index < posts.length; index++)
    if (BookmarkIdentity.tryFromPost(posts[index]) case final identity?)
      if (identities.contains(identity)) index,
];
