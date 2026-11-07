// Project imports:
import '../../../posts/post/types.dart';
import 'bookmark.dart';

abstract class BookmarkRepository<T extends Post> {
  Future<PostBookmark> addBookmark(
    int booruId,
    T post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<T> Function(int? booruId) postLinkGenerator,
  });
  Future<List<PostBookmark>> addBookmarks(
    int booruId,
    Iterable<T> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<T> Function(int? booruId) postLinkGenerator,
  });

  Future<List<PostBookmark>> addBookmarkWithBookmarks(
    List<PostBookmark> bookmarks,
  );

  Future<void> removeBookmark(PostBookmark favorite);
  Future<void> removeBookmarks(Iterable<PostBookmark> favorites);
  Future<void> updateBookmark(PostBookmark favorite);
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  });
}

/// Optional capability for repositories with an authoritative identity index.
/// Standalone services and older repository implementations retain the full-read
/// fallback; a serialized mutation can resolve only the affected identities.
abstract interface class BookmarkIdentityLookup {
  Future<Map<BookmarkUniqueId, PostBookmark>> lookupBookmarks(
    Set<BookmarkUniqueId> identities, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  });
}

class BookmarkRepositoryReadException implements Exception {
  const BookmarkRepositoryReadException(this.error);

  final BookmarkGetError error;
}

extension BookmarkRepositoryExtensions on BookmarkRepository {
  Future<Map<BookmarkUniqueId, PostBookmark>> getBookmarksByIdentityOrThrow(
    Iterable<BookmarkUniqueId> identities, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) async {
    final selected = identities.toSet();
    if (selected.isEmpty) return {};
    final repository = this;
    if (repository is BookmarkIdentityLookup) {
      return (repository as BookmarkIdentityLookup).lookupBookmarks(
        selected,
        imageUrlResolver: imageUrlResolver,
      );
    }
    return {
      for (final bookmark in await getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      ))
        if (selected.contains(bookmark.uniqueId)) bookmark.uniqueId: bookmark,
    };
  }

  Future<List<PostBookmark>> getAllBookmarksOrThrow({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) async {
    final bookmarks = await getAllBookmarks(
      imageUrlResolver: imageUrlResolver,
    ).run();
    return bookmarks.fold(
      (error) => throw BookmarkRepositoryReadException(error),
      (bookmarks) => bookmarks,
    );
  }

  Future<List<PostBookmark>> getAllBookmarksOrEmpty({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) async {
    final bookmarks = await getAllBookmarks(
      imageUrlResolver: imageUrlResolver,
    ).run();
    return bookmarks.fold(
      (error) => <PostBookmark>[],
      (bookmarks) => bookmarks,
    );
  }
}
