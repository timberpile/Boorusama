// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../boorus/booru/types.dart';
import 'bookmark.dart';
import 'bookmark_search_token.dart';

class BookmarkTagSource extends Equatable {
  const BookmarkTagSource({required this.url, required this.booruType});

  final String url;
  final BooruType booruType;

  @override
  List<Object> get props => [url, booruType];
}

class BookmarkTagEntry extends Equatable {
  BookmarkTagEntry({
    required this.tag,
    required this.count,
    required Map<BookmarkTagSource, Set<String>> sources,
  }) : sources = Map.unmodifiable(
         sources.map(
           (source, categories) => MapEntry(
             source,
             Set<String>.unmodifiable(categories),
           ),
         ),
       );

  final String tag;
  final int count;
  // An empty category set means the snapshot has no classification for this tag.
  final Map<BookmarkTagSource, Set<String>> sources;

  @override
  List<Object> get props => [tag, count, sources];
}

class BookmarkTagIndex {
  BookmarkTagIndex(Iterable<BookmarkTagEntry> entries)
    : entries = List.unmodifiable(
        entries.toList()..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.tag.compareTo(b.tag);
        }),
      ),
      byName = Map.unmodifiable({
        for (final entry in entries) entry.tag: entry,
      });

  factory BookmarkTagIndex.fromBookmarks(
    Iterable<Bookmark> bookmarks, {
    String Function(Bookmark bookmark)? siteUrl,
  }) {
    final counts = <String, int>{};
    final sources = <String, Map<BookmarkTagSource, Set<String>>>{};
    for (final bookmark in bookmarks) {
      final source = BookmarkTagSource(
        url: siteUrl?.call(bookmark) ?? bookmark.sourceUrl,
        booruType: bookmark.post.origin.booruType,
      );
      final categorized =
          {
            'artist': bookmark.post.artistTags ?? const <String>{},
            'character': bookmark.post.characterTags ?? const <String>{},
            'copyright': bookmark.post.copyrightTags ?? const <String>{},
          }.map(
            (category, tags) => MapEntry(
              category,
              tags.map(canonicalBookmarkTag).toSet(),
            ),
          );
      for (final tag in bookmark.tags.map(canonicalBookmarkTag).toSet()) {
        if (tag.isEmpty) continue;
        counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
        final categories = sources
            .putIfAbsent(tag, () => {})
            .putIfAbsent(source, () => {});
        for (final entry in categorized.entries) {
          if (entry.value.contains(tag)) categories.add(entry.key);
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

  final List<BookmarkTagEntry> entries;
  final Map<String, BookmarkTagEntry> byName;

  List<BookmarkTagEntry> suggestions(
    String draft, {
    Set<String> selectedTags = const {},
    int limit = 5,
  }) {
    if (draft.trim().isEmpty) {
      return entries
          .where((entry) => !selectedTags.contains(entry.tag))
          .toList();
    }
    if (BookmarkSearchToken.current(draft).tag.isEmpty) {
      return const [];
    }
    for (final query in bookmarkSuggestionQueries(draft)) {
      if (query.token.tag.isEmpty) continue;
      final matches = entries.where(
        (entry) => entry.tag.contains(query.token.tag),
      );
      if (matches.isEmpty) continue;
      // Do not fall back to a shorter word merely because the full phrase is
      // already selected: that would reintroduce irrelevant partial matches.
      return matches
          .where((entry) {
            final canonical =
                '${query.token.isNegative ? '-' : ''}${entry.tag}';
            return !selectedTags.contains(canonical);
          })
          .take(limit)
          .toList();
    }
    return const [];
  }
}
