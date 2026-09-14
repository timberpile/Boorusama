// Project imports:
import '../../../posts/post/types.dart';
import 'bookmark.dart';

abstract class BookmarkRepository<T extends Post> {
  Future<Bookmark> addBookmark(
    int booruId,
    T post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<T> Function(int? booruId) postLinkGenerator,
  });
  Future<List<Bookmark>> addBookmarks(
    int booruId,
    Iterable<T> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator<T> Function(int? booruId) postLinkGenerator,
  });

  Future<List<Bookmark>> addBookmarkWithBookmarks(
    List<Bookmark> bookmarks,
  );

  Future<void> removeBookmark(Bookmark favorite);
  Future<void> removeBookmarks(Iterable<Bookmark> favorites);
  Future<void> updateBookmark(Bookmark favorite);
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  });
}

class BookmarkRepositoryReadException implements Exception {
  const BookmarkRepositoryReadException(this.error);

  final BookmarkGetError error;
}

extension BookmarkRepositoryExtensions on BookmarkRepository {
  Future<List<Bookmark>> getAllBookmarksOrThrow({
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

  Future<List<Bookmark>> getAllBookmarksOrEmpty({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) async {
    final bookmarks = await getAllBookmarks(
      imageUrlResolver: imageUrlResolver,
    ).run();
    return bookmarks.fold(
      (error) => <Bookmark>[],
      (bookmarks) => bookmarks,
    );
  }
}
