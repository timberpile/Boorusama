// Package imports:
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import '../../../../boorus/booru/types.dart';
import '../../../../posts/post/types.dart';
import '../../types/bookmark.dart';
import '../../types/bookmark_repository.dart';
import '../bookmark_convert.dart';
import 'bookmark_hive_object.dart';

class BookmarkHiveRepository implements BookmarkRepository {
  const BookmarkHiveRepository(
    this._box, {
    this.postDataCodec,
  });

  final Box<BookmarkHiveObject> _box;
  final BooruPostDataCodec? Function(BooruType type)? postDataCodec;

  @override
  Future<Bookmark> addBookmark(
    int booruId,
    Post post, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) async {
    final now = DateTime.now();
    final sourceUrl = postLinkGenerator(booruId).getLink(post);
    final storedPost = recoverBookmarkPostOrigin(post, sourceUrl);
    final snapshot = const StoredPostCodec().encode(
      storedPost,
      dataCodec: postDataCodec?.call(storedPost.origin.booruType),
    );
    final bookmark = Bookmark.fromSnapshot(
      id: -1,
      createdAt: now,
      updatedAt: now,
      snapshot: snapshot,
      post: storedPost,
      sourceUrl: sourceUrl,
    );
    final favoriteHiveObject = favoriteToHiveObject(bookmark);
    final id = await _box.add(favoriteHiveObject);

    return bookmark.copyWith(id: id);
  }

  @override
  Future<void> removeBookmark(Bookmark favorite) async {
    await _box.delete(favorite.id);
  }

  @override
  Future<void> removeBookmarks(Iterable<Bookmark> favorites) async {
    await _box.deleteAll(favorites.map((favorite) => favorite.id));
  }

  @override
  Future<void> updateBookmark(Bookmark favorite) async {
    await _box.put(favorite.id, favoriteToHiveObject(favorite));
  }

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) =>
      TaskEither.fromEither(
            tryGetBoxValues(_box).mapLeft(mapBoxErrorToBookmarkGetError),
          )
          .flatMap(
            (objects) => TaskEither.fromEither(
              tryMapBookmarkHiveObjectsWithWriteBack(
                objects,
                imageUrlResolver,
                postDataCodec,
              ),
            ),
          )
          .flatMap(
            (mappings) => TaskEither.tryCatch(
              () async {
                for (final mapping in mappings) {
                  if (mapping.needsWriteBack) {
                    await _box.put(
                      mapping.bookmark.id,
                      favoriteToHiveObject(mapping.bookmark),
                    );
                  }
                }
                return [for (final mapping in mappings) mapping.bookmark];
              },
              (_, _) => BookmarkGetError.unknown,
            ),
          );

  @override
  Future<List<Bookmark>> addBookmarks(
    int booruId,
    Iterable<Post> posts, {
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
    required PostLinkGenerator Function(int? booruId) postLinkGenerator,
  }) {
    final futures = posts.map(
      (post) => addBookmark(
        booruId,
        post,
        imageUrlResolver: imageUrlResolver,
        postLinkGenerator: postLinkGenerator,
      ),
    );

    return Future.wait(futures);
  }

  @override
  Future<List<Bookmark>> addBookmarkWithBookmarks(
    List<Bookmark> bookmarks,
  ) async {
    final hiveObjects = bookmarks.map(favoriteToHiveObject).toList();
    final ids = (await _box.addAll(hiveObjects)).toList();
    return [
      for (var index = 0; index < bookmarks.length; index++)
        bookmarks[index].copyWith(id: ids[index]),
    ];
  }
}
