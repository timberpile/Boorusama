import 'dart:collection';

// Package imports:
import 'package:equatable/equatable.dart';
import 'package:foundation/performance.dart';

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
        performanceRecorder.measureSync(
          PerfOperation.bookmarkTagSort,
          () => entries.toList()
            ..sort((a, b) {
              final byCount = b.count.compareTo(a.count);
              return byCount != 0 ? byCount : a.tag.compareTo(b.tag);
            }),
        ),
      ),
      byName = Map.unmodifiable({
        for (final entry in entries) entry.tag: entry,
      });

  // Both collections are finalized private build buffers. No mutable owner is
  // retained after publication, and previous results never observe later edits.
  BookmarkTagIndex._owned(
    List<BookmarkTagEntry> sorted,
    Map<String, BookmarkTagEntry> names,
  ) : entries = UnmodifiableListView(sorted),
      byName = UnmodifiableMapView(names);

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

/// Maintains counts for a search scope. Only added, removed or replaced
/// snapshots contribute tag work; published indexes remain immutable.
class BookmarkTagIndexBuilder {
  BookmarkTagIndexBuilder({this.siteUrl}) {
    performanceRecorder.count(PerfCounter.bookmarkTagBuilderCreated, 1);
  }

  final String Function(Bookmark bookmark)? siteUrl;
  Map<int, Bookmark> _bookmarks = {};
  final _tags = <String, _TagReferences>{};
  var _index = BookmarkTagIndex(const []);
  var _built = false;
  Object? _lastRevision;
  Future<void> _pending = Future.value();

  BookmarkTagIndex update(Iterable<Bookmark> bookmarks) =>
      performanceRecorder.measureSync(PerfOperation.bookmarkTagUpdate, () {
        for (final _ in _steps(bookmarks)) {}
        return _index;
      });

  /// Serializes updates to this retained builder. Cancellation discards partial
  /// mutable work; a newer generation can never publish an older library.
  Future<BookmarkTagIndex?> updateAsync(
    Iterable<Bookmark> bookmarks, {
    required bool Function() isCurrent,
    Future<void> Function()? yieldControl,
    Object? revision,
  }) {
    final result = _pending.then(
      (_) => performanceRecorder.measureAsync(
        PerfOperation.bookmarkTagUpdateAsync,
        () async {
          if (!isCurrent()) return null;
          var completed = false;
          try {
            for (final _ in _steps(bookmarks, revision: revision)) {
              performanceRecorder.count(PerfCounter.bookmarkTagYields, 1);
              await (yieldControl?.call() ??
                  Future<void>.delayed(Duration.zero));
              if (!isCurrent()) return null;
            }
            completed = true;
            return _index;
          } finally {
            if (!completed) {
              _bookmarks = {};
              _tags.clear();
              _index = BookmarkTagIndex(const []);
              _lastRevision = null;
              _built = false;
            }
          }
        },
      ),
    );
    // A failed generation must not poison the next queued update.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Iterable<void> _steps(
    Iterable<Bookmark> bookmarks, {
    Object? revision,
  }) sync* {
    // Only callers with an immutable revision may skip comparison. Generic
    // callers can mutate a previously supplied List between updates.
    if (revision != null && identical(_lastRevision, revision)) return;
    performanceRecorder.count(
      _built
          ? PerfCounter.bookmarkTagIncrementalBuild
          : PerfCounter.bookmarkTagFullBuild,
      1,
    );
    final next = <int, Bookmark>{};
    for (final batch in _batches(bookmarks, 256)) {
      performanceRecorder.measureSync(PerfOperation.bookmarkTagCompare, () {
        for (final bookmark in batch) {
          next[bookmark.id] = bookmark;
        }
      }, items: batch.length);
      yield null;
    }
    var added = 0;
    var removed = 0;
    var references = 0;
    for (final (rows, delta) in [(_bookmarks.values, -1), (next.values, 1)]) {
      for (final batch in _batches(rows, 32)) {
        final beforeAdded = added;
        final beforeRemoved = removed;
        final beforeReferences = references;
        performanceRecorder.measureSync(PerfOperation.bookmarkTagAggregate, () {
          for (final bookmark in batch) {
            final previous = delta == -1
                ? next[bookmark.id]
                : _bookmarks[bookmark.id];
            if (identical(previous, bookmark)) continue;
            references += _adjust(bookmark, delta);
            if (delta == 1) {
              added++;
            } else {
              removed++;
            }
          }
        }, items: batch.length);
        performanceRecorder.count(
          PerfCounter.bookmarkTagRowsAdded,
          added - beforeAdded,
        );
        performanceRecorder.count(
          PerfCounter.bookmarkTagRowsRemoved,
          removed - beforeRemoved,
        );
        performanceRecorder.count(
          PerfCounter.bookmarkTagReferences,
          references - beforeReferences,
        );
        yield null;
      }
    }
    if (added + removed > 0) {
      final entries = <BookmarkTagEntry>[];
      final names = <String, BookmarkTagEntry>{};
      for (final batch in _batches(_tags.entries, 128)) {
        performanceRecorder.measureSync(PerfOperation.bookmarkTagPublish, () {
          for (final entry in batch) {
            final snapshot = entry.value.snapshot(entry.key);
            entries.add(snapshot);
            names[entry.key] = snapshot;
          }
        }, items: batch.length);
        yield null;
      }
      yield* _sort(entries);
      _index = BookmarkTagIndex._owned(entries, names);
    }
    _bookmarks = next;
    _built = true;
    _lastRevision = revision;
    performanceRecorder.count(PerfCounter.bookmarkTagDistinct, _tags.length);
  }

  // Bottom-up merge sort yields even when almost every tag is distinct. Merely
  // chunking row aggregation would leave snapshot publication/sorting blocking.
  Iterable<void> _sort(List<BookmarkTagEntry> entries) sync* {
    const size = 256;
    for (var start = 0; start < entries.length; start += size) {
      final end = (start + size).clamp(0, entries.length);
      performanceRecorder.measureSync(PerfOperation.bookmarkTagSort, () {
        final batch = entries.sublist(start, end)..sort(_compareEntries);
        entries.setRange(start, end, batch);
      }, items: end - start);
      yield null;
    }
    var input = entries;
    var output = <BookmarkTagEntry>[];
    for (final batch in _batches(entries, 1024)) {
      performanceRecorder.measureSync(
        PerfOperation.bookmarkTagSort,
        () => output.addAll(batch),
        items: batch.length,
      );
      yield null;
    }
    for (var width = size; width < entries.length; width *= 2) {
      for (var start = 0; start < entries.length; start += width * 2) {
        final middle = (start + width).clamp(0, entries.length);
        final end = (start + width * 2).clamp(0, entries.length);
        var left = start;
        var right = middle;
        for (var offset = start; offset < end;) {
          final stop = (offset + 1024).clamp(0, end);
          performanceRecorder.measureSync(PerfOperation.bookmarkTagSort, () {
            while (offset < stop) {
              output[offset++] =
                  right >= end ||
                      (left < middle &&
                          _compareEntries(input[left], input[right]) <= 0)
                  ? input[left++]
                  : input[right++];
            }
          }, items: stop - offset);
          yield null;
        }
      }
      final swap = input;
      input = output;
      output = swap;
    }
    if (!identical(input, entries)) {
      for (var start = 0; start < entries.length; start += 1024) {
        final end = (start + 1024).clamp(0, entries.length);
        performanceRecorder.measureSync(
          PerfOperation.bookmarkTagSort,
          () => entries.setRange(start, end, input, start),
          items: end - start,
        );
        yield null;
      }
    }
  }

  int _adjust(Bookmark bookmark, int delta) {
    final source = performanceRecorder.measureSync(
      PerfOperation.bookmarkTagResolveSource,
      () => BookmarkTagSource(
        url: siteUrl?.call(bookmark) ?? bookmark.sourceUrl,
        booruType: bookmark.post.origin.booruType,
      ),
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
    var references = 0;
    for (final tag in bookmark.tags.map(canonicalBookmarkTag).toSet()) {
      if (tag.isEmpty) continue;
      references++;
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
    return references;
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

int _compareEntries(BookmarkTagEntry a, BookmarkTagEntry b) {
  final byCount = b.count.compareTo(a.count);
  return byCount != 0 ? byCount : a.tag.compareTo(b.tag);
}

Iterable<List<T>> _batches<T>(Iterable<T> items, int size) sync* {
  var batch = <T>[];
  for (final item in items) {
    batch.add(item);
    if (batch.length == size) {
      yield batch;
      batch = <T>[];
    }
  }
  if (batch.isNotEmpty) yield batch;
}
