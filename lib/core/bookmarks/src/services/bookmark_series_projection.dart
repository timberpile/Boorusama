import '../../../posts/post/types.dart';
import '../types/bookmark_grid_entry.dart';

({List<BookmarkGridEntry> entries, Map<Object, int> postIndices})
visibleBookmarkGridEntries(
  List<BookmarkGridEntry> fetched,
  List<Post> visiblePosts,
) {
  final byObject = Map<Post, int>.identity();
  for (final (index, post) in visiblePosts.indexed) {
    byObject[post] = index;
  }
  final entries = <BookmarkGridEntry>[];
  final indices = <Object, int>{};
  for (final entry in fetched) {
    if (entry is! BookmarkPostEntry) {
      entries.add(entry);
      continue;
    }
    final post = entry.bookmark.post;
    final index = byObject[post];
    if (index == null) continue;
    entries.add(entry);
    indices[entry.key] = index;
  }
  return (entries: entries, postIndices: indices);
}
