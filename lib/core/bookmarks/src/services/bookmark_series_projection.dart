import '../../../posts/post/types.dart';
import '../types/bookmark_identity.dart';
import '../types/bookmark_grid_entry.dart';

({List<BookmarkGridEntry> entries, Map<Object, int> postIndices})
visibleBookmarkGridEntries(
  List<BookmarkGridEntry> fetched,
  List<Post> visiblePosts,
) {
  final byObject = Map<Post, int>.identity();
  final byIdentity = <BookmarkIdentity, int>{};
  for (final (index, post) in visiblePosts.indexed) {
    byObject[post] = index;
    if (BookmarkIdentity.tryFromPost(post) case final id?)
      byIdentity[id] = index;
  }
  final entries = <BookmarkGridEntry>[];
  final indices = <Object, int>{};
  for (final entry in fetched) {
    if (entry is BookmarkPoolEntry) {
      entries.add(entry);
      continue;
    }
    final post = (entry as BookmarkPostEntry).bookmark.post;
    final index =
        byObject[post] ?? byIdentity[BookmarkIdentity.tryFromPost(post)];
    if (index == null) continue;
    entries.add(entry);
    indices[entry.key] = index;
  }
  return (entries: entries, postIndices: indices);
}
