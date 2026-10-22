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

/// Maintains counts for a mounted search scope. Only added, removed or replaced
/// snapshots contribute tag work; published indexes remain immutable.
class BookmarkTagIndexBuilder {
  BookmarkTagIndexBuilder({this.siteUrl});

  final String Function(Bookmark bookmark)? siteUrl;
  Map<int, Bookmark> _bookmarks = {};
  final _tags = <String, _TagReferences>{};
  var _index = BookmarkTagIndex(const []);

  BookmarkTagIndex update(Iterable<Bookmark> bookmarks) {
    final next = {for (final bookmark in bookmarks) bookmark.id: bookmark};
    var changed = false;
    for (final old in _bookmarks.values) {
      if (!identical(next[old.id], old)) {
        _adjust(old, -1);
        changed = true;
      }
    }
    for (final bookmark in next.values) {
      if (!identical(_bookmarks[bookmark.id], bookmark)) {
        _adjust(bookmark, 1);
        changed = true;
      }
    }
    _bookmarks = next;
    if (changed) {
      _index = BookmarkTagIndex([
        for (final entry in _tags.entries) entry.value.snapshot(entry.key),
      ]);
    }
    return _index;
  }

  void _adjust(Bookmark bookmark, int delta) {
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
      final refs = _tags.putIfAbsent(tag, _TagReferences.new);
      refs.cached = null;
      refs.count += delta;
      final sourceRefs = refs.sources.putIfAbsent(
        source,
        _SourceReferences.new,
      );
      sourceRefs.count += delta;
      for (final entry in categorized.entries) {
        if (!entry.value.contains(tag)) continue;
        final count = (sourceRefs.categories[entry.key] ?? 0) + delta;
        if (count == 0) {
          sourceRefs.categories.remove(entry.key);
        } else {
          sourceRefs.categories[entry.key] = count;
        }
      }
      if (sourceRefs.count == 0) refs.sources.remove(source);
      if (refs.count == 0) _tags.remove(tag);
    }
  }
}

class _TagReferences {
  var count = 0;
  final sources = <BookmarkTagSource, _SourceReferences>{};
  BookmarkTagEntry? cached;

  BookmarkTagEntry snapshot(String tag) => cached ??= BookmarkTagEntry(
    tag: tag,
    count: count,
    sources: {
      for (final entry in sources.entries)
        entry.key: entry.value.categories.keys.toSet(),
    },
  );
}

class _SourceReferences {
  var count = 0;
  final categories = <String, int>{};
}
