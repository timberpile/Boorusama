import '../../../posts/post/types.dart';
import '../types/bookmark_identity.dart';
import '../../../posts/listing/src/types/neighboring_series.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/pool_bookmark.dart';

final class BookmarkSeriesMembership {
  const BookmarkSeriesMembership({
    required this.scope,
    required this.pools,
    this.observedAt,
  });
  final DateTime? observedAt;
  final Object scope;
  final Map<int, PoolBookmark> pools;
}

final class BookmarkDisplayEntry {
  const BookmarkDisplayEntry({
    required this.firstIndex,
    required this.endIndex,
    required this.entry,
    this.series,
  });
  final int firstIndex;
  final int endIndex;
  final BookmarkGridEntry entry;
  final PoolBookmark? series;
  Object get key =>
      series == null ? entry.key : ('series', series!.identity, entry.key);
}

List<BookmarkDisplayEntry> projectBookmarkSeries(
  List<BookmarkGridEntry> entries,
  Map<Object, BookmarkSeriesMembership> memberships, {
  int start = 0,
  bool enabled = true,
}) => [
  for (final run in groupNeighboringSeries(
    entries.sublist(start),
    enabled: enabled,
    scopeKey: (entry) =>
        entry is BookmarkPostEntry ? memberships[entry.key]?.scope : null,
    seriesIds: (entry) => memberships[entry.key]?.pools.entries
        .where((p) => p.value.category == BookmarkedPoolCategory.series)
        .map((p) => p.key),
  ))
    BookmarkDisplayEntry(
      firstIndex: start + run.firstIndex,
      endIndex: start + run.firstIndex + run.posts.length,
      entry: run.posts.first,
      series: run.seriesId == null
          ? null
          : memberships[run.posts.first.key]?.pools[run.seriesId],
    ),
];

/// Keep every built/cached tile unchanged. Deferred metadata may project only
/// the unseen suffix, so incoming requests cannot move the viewport's anchor.
List<BookmarkDisplayEntry> updateUnseenBookmarkSeries({
  required List<BookmarkGridEntry> entries,
  required List<BookmarkDisplayEntry> displayed,
  required Map<Object, BookmarkSeriesMembership> memberships,
  required int frozenUntil,
}) {
  final prefix = displayed.where((e) => e.firstIndex < frozenUntil).toList();
  final start = prefix.lastOrNull?.endIndex ?? 0;
  return [
    ...prefix,
    ...projectBookmarkSeries(entries, memberships, start: start),
  ];
}

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
