/// One tile's consecutive posts in the filtered source list.
///
/// A null [seriesId] denotes an ordinary, single-post tile. Source indices are
/// retained so grouping does not change pagination, selection, or viewer data.
class NeighboringSeriesEntry<T> {
  NeighboringSeriesEntry._({
    required this.firstIndex,
    required List<T> posts,
    required this.seriesId,
  }) : posts = List.unmodifiable(posts);

  final int firstIndex;
  final List<T> posts;
  final int? seriesId;
}

/// Projects a filtered, ordered list into neighboring series runs.
///
/// [seriesIds] must return only confirmed *series* memberships, not collection
/// IDs, parent IDs, or inferred tag relationships. Null/empty membership and a
/// null [scopeKey] leave a post ungrouped. The scope must identify both the site
/// and originating profile, including the relevant authentication context.
///
/// Every post in a group shares the same scope and at least one series ID.
/// Starting at each unconsumed post, the longest shared-series prefix wins;
/// the smallest ID breaks ties. Posts are never reordered or discarded.
///
/// This function performs no I/O. Resolve metadata before calling it, outside
/// widget builds. Keep the original post list as the controller's source of
/// truth; these entries are a presentation projection, not replacement posts.
List<NeighboringSeriesEntry<T>> groupNeighboringSeries<T>(
  List<T> posts, {
  required Object? Function(T post) scopeKey,
  required Iterable<int>? Function(T post) seriesIds,
  bool enabled = true,
}) {
  final entries = <NeighboringSeriesEntry<T>>[];
  var start = 0;

  Set<int> knownSeries(T post) => (seriesIds(post) ?? const <int>[])
      .where((id) => id > 0)
      .toSet();

  while (start < posts.length) {
    final scope = enabled ? scopeKey(posts[start]) : null;
    var common = scope == null ? <int>{} : knownSeries(posts[start]);
    var end = start + 1;

    while (common.isNotEmpty && end < posts.length) {
      final next = posts[end];
      if (scopeKey(next) != scope) break;

      // Pairwise overlap is insufficient: A, A+B, B is not one series run.
      final shared = common.intersection(knownSeries(next));
      if (shared.isEmpty) break;

      common = shared;
      end++;
    }

    entries.add(
      NeighboringSeriesEntry._(
        firstIndex: start,
        posts: posts.sublist(start, end),
        seriesId: end - start > 1
            ? common.reduce((a, b) => a < b ? a : b)
            : null,
      ),
    );
    start = end;
  }

  return List.unmodifiable(entries);
}
