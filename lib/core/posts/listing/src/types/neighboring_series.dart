/// One display tile, retaining every member's filtered raw-source index.
/// A null [seriesId] denotes an ordinary single-post tile.
class NeighboringSeriesEntry<T> {
  NeighboringSeriesEntry._({
    required List<int> indices,
    required List<T> posts,
    required this.seriesId,
  }) : indices = List.unmodifiable(indices),
       posts = List.unmodifiable(posts);

  final List<int> indices;
  final List<T> posts;
  final int? seriesId;
  int get firstIndex => indices.first;
  int get lastIndex => indices.last;
}

/// Projects confirmed Series using a rolling five-result lookahead.
///
/// The earliest unclaimed post owns a group. Each candidate Series scans the
/// next five raw positions after its last match, extending on every match.
/// Most members wins; the lowest Series ID breaks ties. Intervening posts keep
/// their positions and may start independent, overlapping-window groups.
/// Scope identifies site/profile/auth; missing metadata never implies membership.
/// No I/O occurs and the controller's raw list remains the source of truth.
///
/// [frozen] preserves built tiles, including noncontiguous member indices. A
/// frozen Series may absorb only unbuilt posts within its rolling window; it
/// never steals a frozen tile or changes its cover, identity or position.
List<NeighboringSeriesEntry<T>> groupNeighboringSeries<T>(
  List<T> posts, {
  required Object? Function(T post) scopeKey,
  required Iterable<int>? Function(T post) seriesIds,
  bool enabled = true,
  List<NeighboringSeriesEntry<T>> frozen = const [],
}) {
  final memberships = [
    for (final post in posts)
      enabled
          ? (seriesIds(post) ?? const <int>[]).where((id) => id > 0).toSet()
          : <int>{},
  ];
  final fixed = enabled
      ? {for (final e in frozen) e.firstIndex: e}
      : <int, NeighboringSeriesEntry<T>>{};
  final claimed = {for (final e in fixed.values) ...e.indices};
  final entries = <NeighboringSeriesEntry<T>>[];

  List<int> extend(List<int> seed, int id, Object scope) {
    final indices = [...seed];
    for (
      var i = indices.last + 1;
      i < posts.length && i <= indices.last + 5;
      i++
    ) {
      if (!claimed.contains(i) &&
          scopeKey(posts[i]) == scope &&
          memberships[i].contains(id)) {
        indices.add(i);
      }
    }
    return indices;
  }

  for (var start = 0; start < posts.length; start++) {
    final retained = fixed[start];
    if (claimed.contains(start) && retained == null) continue;
    final scope = enabled ? scopeKey(posts[start]) : null;
    var indices = retained?.indices ?? [start];
    int? series = retained?.seriesId;
    if (scope != null) {
      if (series != null) {
        indices = extend(indices, series, scope);
      } else if (retained == null) {
        for (final id in memberships[start]) {
          final candidate = extend([start], id, scope);
          if (candidate.length > indices.length ||
              (candidate.length == indices.length &&
                  candidate.length > 1 &&
                  id < series!)) {
            indices = candidate;
            series = id;
          }
        }
      }
    }
    claimed.addAll(indices);
    entries.add(
      NeighboringSeriesEntry._(
        indices: indices,
        posts: [for (final i in indices) posts[i]],
        seriesId: series,
      ),
    );
  }
  return List.unmodifiable(entries);
}
