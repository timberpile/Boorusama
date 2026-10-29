import 'package:equatable/equatable.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../bookmarks/src/types/bookmark_search_token.dart';
import '../../../../bookmarks/src/types/bookmark_tag_index.dart';
import '../../../../posts/post/types.dart';

enum CachedTopicFeedSort {
  stored,
  newest,
  oldest,
  scoreDescending,
  scoreAscending,
}

/// A local projection only. It never changes a Topic query or fetches history.
class CachedTopicFeedFilter extends Equatable {
  const CachedTopicFeedFilter({
    this.query = '',
    this.sourceHost,
    this.sort = CachedTopicFeedSort.stored,
  });

  final String query;
  final String? sourceHost;
  final CachedTopicFeedSort sort;

  bool get isActive =>
      query.trim().isNotEmpty ||
      sourceHost != null ||
      sort != CachedTopicFeedSort.stored;

  List<StoredPostSnapshot> apply(Iterable<StoredPostSnapshot> snapshots) {
    if (!isActive) return snapshots.toList(growable: false);
    final tokens = parseBookmarkSearchInput(query)
        .map(BookmarkSearchToken.parse)
        .toList();
    final host = sourceHost == null
        ? null
        : normalizePostSourceHost(sourceHost!);
    final filtered = [
      for (final snapshot in snapshots)
        if ((host == null ||
                normalizePostSourceHost(snapshot.origin.sourceHost) == host) &&
            _matches(_tags(snapshot), tokens))
          snapshot,
    ];
    if (sort != CachedTopicFeedSort.stored) {
      filtered.sort((a, b) => _compareSnapshots(a, b, sort));
    }
    return filtered;
  }

  @override
  List<Object?> get props => [query, sourceHost, sort];
}

int _compareSnapshots(
  StoredPostSnapshot a,
  StoredPostSnapshot b,
  CachedTopicFeedSort sort,
) {
  if (sort == CachedTopicFeedSort.scoreAscending ||
      sort == CachedTopicFeedSort.scoreDescending) {
    final score = _score(a).compareTo(_score(b));
    if (score != 0) {
      return sort == CachedTopicFeedSort.scoreDescending ? -score : score;
    }
  }
  final aDate = _date(a);
  final bDate = _date(b);
  // Missing upload dates stay last in either direction, including score ties.
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  if (aDate != null && bDate != null) {
    final date = aDate.compareTo(bDate);
    if (date != 0) return sort == CachedTopicFeedSort.oldest ? date : -date;
  }
  final host = a.origin.sourceHost.compareTo(b.origin.sourceHost);
  if (host != 0) return host;
  final engine = a.origin.booruTypeId.compareTo(b.origin.booruTypeId);
  if (engine != 0) return engine;
  final id = _id(a).compareTo(_id(b));
  if (id != 0) return id;
  return (a.origin.profileIdHint ?? '').compareTo(b.origin.profileIdHint ?? '');
}

// Legacy snapshots already use zero when score metadata was never captured.
num _score(StoredPostSnapshot post) => switch (post.common['score']) {
  final num value when value.isFinite => value,
  _ => 0,
};
int _id(StoredPostSnapshot post) => switch (post.common['id']) {
  final int value => value,
  _ => 0,
};
DateTime? _date(StoredPostSnapshot post) => switch (post.common['createdAt']) {
  final String value => DateTime.tryParse(value),
  _ => null,
};

bool _matches(Set<String> tags, List<BookmarkSearchToken> tokens) =>
    tokens.every(
      (token) => token.isNegative
          ? !tags.contains(token.tag)
          : tags.contains(token.tag),
    );

Set<String> _tags(StoredPostSnapshot snapshot) =>
    switch (snapshot.common['tags']) {
      final Iterable tags =>
        tags
            .whereType<String>()
            .map(canonicalBookmarkTag)
            .where((tag) => tag.isNotEmpty)
            .toSet(),
      _ => const {},
    };

List<String> cachedTopicFeedSourceHosts(
  Iterable<StoredPostSnapshot> snapshots,
) =>
    (snapshots
        .map((post) => normalizePostSourceHost(post.origin.sourceHost))
        .where((host) => host.isNotEmpty)
        .toSet()
        .toList()
      ..sort());

BookmarkTagIndex cachedTopicFeedTagIndex(
  Iterable<StoredPostSnapshot> snapshots, {
  String? sourceHost,
  String Function(StoredPostSnapshot snapshot)? siteUrl,
}) {
  final counts = <String, int>{};
  final sources = <String, Map<BookmarkTagSource, Set<String>>>{};
  final host = sourceHost == null ? null : normalizePostSourceHost(sourceHost);
  for (final snapshot in snapshots) {
    if (host != null &&
        normalizePostSourceHost(snapshot.origin.sourceHost) != host) {
      continue;
    }
    final source = BookmarkTagSource(
      url: siteUrl?.call(snapshot) ?? snapshot.origin.sourceHost,
      booruType: BooruType.fromLegacyId(snapshot.origin.booruTypeId),
    );
    final categories = {
      for (final category in ['artist', 'character', 'copyright'])
        category: switch (snapshot.common['${category}Tags']) {
          final Iterable tags =>
            tags.whereType<String>().map(canonicalBookmarkTag).toSet(),
          _ => const <String>{},
        },
    };
    for (final tag in _tags(snapshot)) {
      counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
      final tagCategories = sources
          .putIfAbsent(tag, () => {})
          .putIfAbsent(source, () => {});
      for (final category in categories.entries) {
        if (category.value.contains(tag)) tagCategories.add(category.key);
      }
    }
  }
  return BookmarkTagIndex([
    for (final entry in counts.entries)
      BookmarkTagEntry(
        tag: entry.key,
        count: entry.value,
        sources: sources[entry.key]!,
      ),
  ]);
}
