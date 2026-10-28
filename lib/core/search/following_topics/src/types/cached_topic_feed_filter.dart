import 'package:equatable/equatable.dart';

import '../../../../boorus/booru/types.dart';
import '../../../../bookmarks/src/types/bookmark_search_token.dart';
import '../../../../bookmarks/src/types/bookmark_tag_index.dart';
import '../../../../posts/post/types.dart';

/// A local projection only. It never changes a Topic query or fetches history.
class CachedTopicFeedFilter extends Equatable {
  const CachedTopicFeedFilter({this.query = '', this.sourceHost});

  final String query;
  final String? sourceHost;

  bool get isActive => query.trim().isNotEmpty || sourceHost != null;

  List<StoredPostSnapshot> apply(Iterable<StoredPostSnapshot> snapshots) {
    if (!isActive) return snapshots.toList(growable: false);
    final tokens = parseBookmarkSearchInput(query)
        .map(BookmarkSearchToken.parse)
        .toList();
    final host = sourceHost == null
        ? null
        : normalizePostSourceHost(sourceHost!);
    return [
      for (final snapshot in snapshots)
        if ((host == null ||
                normalizePostSourceHost(snapshot.origin.sourceHost) == host) &&
            _matches(_tags(snapshot), tokens))
          snapshot,
    ];
  }

  @override
  List<Object?> get props => [query, sourceHost];
}

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
