import 'package:foundation/foundation.dart';

import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_repository.dart';

/// A write-through view of the already loaded library for ONE serialized
/// operation. This is not a second long-lived cache. The notifier owns the
/// serialization boundary and discards this view when the operation ends.
///
/// Only successful writes enter the delta. Any ambiguous storage failure
/// permanently disables indexed reads for this operation, including during
/// rollback, so commit-then-throw recovery still sees the actual repository.
class BookmarkMutationRepository
    implements BookmarkRepository<Post>, BookmarkIdentityLookup {
  BookmarkMutationRepository({required this.delegate, required this.base});

  final BookmarkRepository delegate;
  final BookmarkLibraryState base;
  final _upserts = <int, Bookmark>{};
  final _upsertsByIdentity = <BookmarkUniqueId, Bookmark>{};
  final _removedIds = <int>{};
  var _valid = true;

  bool get isValid => _valid;
  Iterable<Bookmark> get upserts => _upserts.values;
  Set<int> get removedIds => Set.unmodifiable(_removedIds);

  void invalidate() => _valid = false;

  void _record(Bookmark bookmark) {
    final previous = _upserts[bookmark.id];
    if (previous != null) _upsertsByIdentity.remove(previous.uniqueId);
    _removedIds.remove(bookmark.id);
    _upserts[bookmark.id] = bookmark;
    _upsertsByIdentity[bookmark.uniqueId] = bookmark;
  }

  void _recordRemoval(Bookmark bookmark) {
    final previous = _upserts.remove(bookmark.id);
    if (previous != null) _upsertsByIdentity.remove(previous.uniqueId);
    _removedIds.add(bookmark.id);
  }

  Future<T> _write<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (_) {
      invalidate();
      rethrow;
    }
  }

  Bookmark? _lookup(BookmarkUniqueId identity) {
    final updated = _upsertsByIdentity[identity];
    if (updated != null) return updated;
    final original = base.bookmarksByUniqueId[identity];
    if (original == null ||
        _removedIds.contains(original.id) ||
        _upserts.containsKey(original.id)) {
      return null;
    }
    return original;
  }

  @override
  Future<Map<BookmarkUniqueId, Bookmark>> lookupBookmarks(
    Set<BookmarkUniqueId> identities, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) async {
    if (!_valid) {
      return delegate.getBookmarksByIdentityOrThrow(
        identities,
        imageUrlResolver: imageUrlResolver,
      );
    }
    return {
      for (final identity in identities)
        if (_lookup(identity) case final bookmark?) identity: bookmark,
    };
  }

  List<Bookmark> _items() {
    if (_upserts.isEmpty && _removedIds.isEmpty) return base.items;
    final remaining = Map<int, Bookmark>.of(_upserts);
    return List.unmodifiable([
      for (final original in base.items)
        if (remaining.remove(original.id) case final updated?)
          updated
        else if (!_removedIds.contains(original.id))
          original,
      ...remaining.values,
    ]);
  }

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) => !_valid
      ? delegate.getAllBookmarks(imageUrlResolver: imageUrlResolver)
      : TaskEither.right(_items());

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<Post> Function(int? booruId) postLinkGenerator,
  }) async {
    final saved = await _write(
      () => delegate.addBookmark(
        booruId,
        post,
        imageUrlResolver: imageUrlResolver,
        postLinkGenerator: postLinkGenerator,
      ),
    );
    _record(saved);
    return saved;
  }

  @override
  Future<List<Bookmark>> addBookmarks(
    int booruId,
    Iterable<Post> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<Post> Function(int? booruId) postLinkGenerator,
  }) async {
    final saved = await _write(
      () => delegate.addBookmarks(
        booruId,
        posts,
        imageUrlResolver: imageUrlResolver,
        postLinkGenerator: postLinkGenerator,
      ),
    );
    for (final bookmark in saved) {
      _record(bookmark);
    }
    return saved;
  }

  @override
  Future<List<Bookmark>> addBookmarkWithBookmarks(
    List<Bookmark> bookmarks,
  ) async {
    final saved = await _write(
      () => delegate.addBookmarkWithBookmarks(bookmarks),
    );
    for (final bookmark in saved) {
      _record(bookmark);
    }
    return saved;
  }

  @override
  Future<void> updateBookmark(Bookmark bookmark) async {
    await _write(() => delegate.updateBookmark(bookmark));
    _record(bookmark);
  }

  @override
  Future<void> removeBookmark(Bookmark bookmark) async {
    await _write(() => delegate.removeBookmark(bookmark));
    _recordRemoval(bookmark);
  }

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> bookmarks) async {
    final selected = bookmarks.toList();
    if (selected.isEmpty) return;
    await _write(() => delegate.removeBookmarks(selected));
    for (final bookmark in selected) {
      _recordRemoval(bookmark);
    }
  }
}
