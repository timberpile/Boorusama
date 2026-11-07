import 'package:foundation/foundation.dart';

import '../../../posts/post/types.dart';
import '../../../boorus/booru/types.dart';
import '../../../content/types.dart';
import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_record_fields.dart';
import '../types/unified_bookmark_store.dart';
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
    implements
        BookmarkRepository<Post>,
        BookmarkIdentityLookup,
        UnifiedBookmarkStore {
  BookmarkMutationRepository({required this.delegate, required this.base})
    : _revision = base.revision;

  final BookmarkRepository delegate;
  final BookmarkLibraryState base;
  final _upserts = <int, Bookmark>{};
  final _upsertsByContent = <ContentIdentity, Bookmark>{};
  int _revision;
  int get revision => _revision;
  final _upsertsByIdentity = <BookmarkUniqueId, PostBookmark>{};
  final _removedIds = <int>{};
  var _valid = true;

  bool get isValid => _valid;
  Iterable<Bookmark> get upserts => _upserts.values;
  Set<int> get removedIds => Set.unmodifiable(_removedIds);

  void invalidate() => _valid = false;

  void recordCommittedChange(BookmarkCommittedChange change) {
    if (!_valid) return;
    if (change.revision < _revision) {
      invalidate();
      return;
    }
    for (final id in change.removedIds) {
      _recordRemovalById(id);
    }
    for (final record in change.records) {
      _record(record);
    }
    _revision = change.revision;
  }

  void _forgetIndexes(Bookmark? previous) {
    if (previous == null) return;
    if (previous is PostBookmark) _upsertsByIdentity.remove(previous.uniqueId);
    final identity = bookmarkContentIdentity(previous);
    if (identity != null) _upsertsByContent.remove(identity);
  }

  void _record(Bookmark bookmark) {
    if (!_valid) return;
    _forgetIndexes(_upserts[bookmark.id]);
    _removedIds.remove(bookmark.id);
    _upserts[bookmark.id] = bookmark;
    if (bookmark is PostBookmark) {
      _upsertsByIdentity[bookmark.uniqueId] = bookmark;
    }
    final identity = bookmarkContentIdentity(bookmark);
    if (identity != null) _upsertsByContent[identity] = bookmark;
  }

  void _recordRemovalById(int id) {
    if (!_valid) return;
    _forgetIndexes(_upserts.remove(id));
    _removedIds.add(id);
  }

  void _recordRemoval(PostBookmark bookmark) => _recordRemovalById(bookmark.id);

  UnifiedBookmarkStore? get _store => unifiedBookmarkStorage(delegate);

  UnifiedBookmarkStore get _requiredStore =>
      _store ?? (throw StateError('Unified Bookmark storage unavailable'));

  @override
  bool get supportsUnifiedRecords => _store != null;
  @override
  Future<int> readRevision() => _requiredStore.readRevision();
  @override
  Future<T> runReadWriteScope<T>(Future<T> Function() operation) =>
      _requiredStore.runReadWriteScope(operation);
  @override
  Bookmark normalizeRecord(Bookmark record) =>
      _requiredStore.normalizeRecord(record);
  @override
  Future<List<int>> reserveIds(int count) =>
      _write(() => _requiredStore.reserveIds(count));
  @override
  Future<Bookmark?> read(int id) async {
    if (!_valid) return _requiredStore.read(id);
    if (_removedIds.contains(id)) return null;
    return _upserts[id] ?? base.byId[id];
  }

  @override
  Future<List<Bookmark>> readAll() async {
    if (!_valid) return _requiredStore.readAll();
    final records = {...base.byId}
      ..removeWhere((id, _) => _removedIds.contains(id));
    records.addAll(_upserts);
    return List.unmodifiable(
      records.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
    );
  }

  @override
  Future<Bookmark?> lookupContent(
    ContentIdentity identity, {
    required BooruType engine,
  }) async {
    if (!_valid) return _requiredStore.lookupContent(identity, engine: engine);
    final changed = _upsertsByContent[identity];
    final baseId = base.idByContent[identity];
    final record =
        changed ??
        (baseId == null ||
                _removedIds.contains(baseId) ||
                _upserts.containsKey(baseId)
            ? null
            : base.byId[baseId]);
    if (record != null && bookmarkEngine(record) != engine) {
      throw const FormatException('Incompatible content engines');
    }
    return record;
  }

  @override
  Future<void> upsert(Bookmark bookmark) => upsertAll([bookmark]);
  @override
  Future<void> upsertAll(Iterable<Bookmark> bookmarks) =>
      _write(() => _requiredStore.upsertAll(bookmarks));
  @override
  Future<void> delete(int id) => _write(() => _requiredStore.delete(id));
  @override
  Future<void> durableSync() => _requiredStore.durableSync();
  @override
  Future<void> commitOrganization({
    Iterable<Bookmark> records = const [],
    Set<int> removeIds = const {},
    List<BookmarkGroup> groups = const [],
    Set<String> removeGroupIds = const {},
    List<CollectionFolder>? folders,
  }) => _write(
    () => _requiredStore.commitOrganization(
      records: records,
      removeIds: removeIds,
      groups: groups,
      removeGroupIds: removeGroupIds,
      folders: folders,
    ),
  );

  Future<T> _write<T>(Future<T> Function() operation) async {
    try {
      return await observeBookmarkWrites(operation, recordCommittedChange);
    } catch (_) {
      invalidate();
      rethrow;
    }
  }

  PostBookmark? _lookup(BookmarkUniqueId identity) {
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
  Future<Map<BookmarkUniqueId, PostBookmark>> lookupBookmarks(
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

  List<PostBookmark> _items() {
    if (_upserts.isEmpty && _removedIds.isEmpty) return base.items;
    final remaining = <int, PostBookmark>{
      for (final record in _upserts.values)
        if (record is PostBookmark) record.id: record,
    };
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
  Future<PostBookmark> addBookmark(
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
  Future<List<PostBookmark>> addBookmarks(
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
  Future<List<PostBookmark>> addBookmarkWithBookmarks(
    List<PostBookmark> bookmarks,
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
  Future<void> updateBookmark(PostBookmark bookmark) async {
    await _write(() => delegate.updateBookmark(bookmark));
    _record(bookmark);
  }

  @override
  Future<void> removeBookmark(PostBookmark bookmark) async {
    await _write(() => delegate.removeBookmark(bookmark));
    _recordRemoval(bookmark);
  }

  @override
  Future<void> removeBookmarks(Iterable<PostBookmark> bookmarks) async {
    final selected = bookmarks.toList();
    if (selected.isEmpty) return;
    await _write(() => delegate.removeBookmarks(selected));
    for (final bookmark in selected) {
      _recordRemoval(bookmark);
    }
  }
}
