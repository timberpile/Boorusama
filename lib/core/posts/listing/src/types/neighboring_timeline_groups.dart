import '../../../post/types.dart';
import '../../../related/related_family.dart';
import '../../../../boorus/booru/types.dart';
import 'neighboring_series.dart';

/// Presentation only; family identity is the shared RelatedFamilyReference.
class NeighboringTimelineEntry {
  NeighboringTimelineEntry._(this.projection, {this.family});
  final NeighboringSeriesEntry<Post> projection;
  final RelatedFamilyReference? family;
  List<int> get indices => projection.indices;
  List<Post> get posts => projection.posts;
  int get firstIndex => projection.firstIndex;
  int get lastIndex => projection.lastIndex;
  int? get seriesId => family == null ? projection.seriesId : null;
}

class _RelatedMembers {
  _RelatedMembers(this.family, List<int> indices) : indices = [...indices];
  final RelatedFamilyReference family;
  final List<int> indices;
}

/// Series retains its rolling window; Related has one representative per family.
/// Frozen entries reserve their indices before either pass claims new members.
List<NeighboringTimelineEntry> groupNeighboringTimeline(
  List<Post> posts, {
  required Object? Function(Post) scopeKey,
  required Iterable<int>? Function(Post) seriesIds,
  bool enabled = true,
  bool relatedEnabled = true,
  List<NeighboringTimelineEntry> frozen = const [],
}) {
  final retained = enabled
      ? frozen.where((entry) => relatedEnabled || entry.family == null).toList()
      : const <NeighboringTimelineEntry>[];
  final series = groupNeighboringSeries(
    posts,
    scopeKey: scopeKey,
    seriesIds: seriesIds,
    enabled: enabled,
    frozen: [
      for (final entry in retained)
        entry.family == null
            ? entry.projection
            : entry.projection.asUngrouped(),
    ],
  );
  final fixed = {for (final entry in retained) entry.firstIndex: entry};
  final families = <(Object, Object), _RelatedMembers>{};
  final related = <int, _RelatedMembers>{};
  // Reconstruct the registry from frozen cards, rather than keeping another
  // mutable session cache. These members are already reserved by the Series pass.
  for (final entry in retained) {
    final family = entry.family;
    final scope = scopeKey(entry.posts.first);
    if (family == null || scope == null) continue;
    final members = _RelatedMembers(family, entry.indices);
    families[(scope, family.identity)] = members;
    related[entry.firstIndex] = members;
  }
  final displayed = <NeighboringSeriesEntry<Post>>[];
  for (final entry in series) {
    if (!enabled ||
        !relatedEnabled ||
        entry.seriesId != null ||
        fixed.containsKey(entry.firstIndex)) {
      displayed.add(entry);
      continue;
    }
    final post = entry.posts.first;
    final scope = scopeKey(post);
    if (scope == null ||
        post.origin.booruType != BooruType.danbooru ||
        post.origin.sourceHost.isEmpty ||
        post.id <= 0) {
      displayed.add(entry);
      continue;
    }
    final family = RelatedFamilyReference.fromPost(post);
    final key = (scope, family.identity);
    if (families[key] case final existing?) {
      existing.indices.addAll(entry.indices);
    } else if (post.hasParent || post.hasParentOrChildren) {
      final members = _RelatedMembers(family, entry.indices);
      families[key] = members;
      related[entry.firstIndex] = members;
      displayed.add(entry);
    } else {
      // fromPost supplies an anchor even for unrelated Posts; it is not proof.
      displayed.add(entry);
    }
  }
  return List.unmodifiable([
    for (final entry in displayed)
      NeighboringTimelineEntry._(
        switch (related[entry.firstIndex]) {
          final members? => NeighboringSeriesEntry.fromIndices(
            posts,
            members.indices,
          ),
          null => entry,
        },
        family: related[entry.firstIndex]?.family,
      ),
  ]);
}
