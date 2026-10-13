import 'package:foundation/performance.dart';

// Package imports:
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../boorus/booru/types.dart';
import '../../../posts/position/types.dart';
import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import 'hive/bookmark_hive_object.dart';

BookmarkGetError mapBoxErrorToBookmarkGetError(BoxError error) =>
    switch (error) {
      BoxError.boxClosed => BookmarkGetError.databaseClosed,
      BoxError.unknown => BookmarkGetError.unknown,
    };

Either<BookmarkGetError, List<Bookmark>> tryMapBookmarkHiveObjectsToBookmarks(
  Iterable<BookmarkHiveObject> hiveObjects,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
]) => Either.tryCatch(
  () => performanceRecorder.measureSync(
    PerfOperation.bookmarkDecodeAll,
    () => hiveObjects
        .where((row) => row.snapshotSchemaVersion == 2)
        .map((row) => _mapBookmark(row, postDataCodec))
        .toList(),
  ),
  (_, _) => BookmarkGetError.nullField,
);

Either<BookmarkGetError, Bookmark> tryMapBookmarkHiveObjectToBookmark(
  BookmarkHiveObject hiveObject,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
]) => Either.tryCatch(
  () => _mapBookmark(hiveObject, postDataCodec),
  (_, _) => BookmarkGetError.nullField,
);

Bookmark _mapBookmark(
  BookmarkHiveObject row,
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
) {
  if (row.snapshotSchemaVersion != 2 || row.postSnapshot == null) {
    throw const FormatException('Unsupported bookmark row');
  }
  final snapshot = StoredPostSnapshot.fromJson(
    Map<String, dynamic>.from(row.postSnapshot!),
  );
  final type = BooruType.fromLegacyId(snapshot.origin.booruTypeId);
  final decoded = const StoredPostCodec().decode(
    snapshot,
    dataCodec: postDataCodec?.call(type),
  );
  if (decoded case StoredPostDecodeSuccess(:final post)) {
    if (row.postId != post.id ||
        BookmarkIdentity.tryFromPost(post) == null ||
        row.createdAt == null ||
        row.updatedAt == null) {
      throw const FormatException('Invalid bookmark snapshot identity');
    }
    return Bookmark.fromSnapshot(
      id: row.key,
      createdAt: row.createdAt!,
      updatedAt: row.updatedAt!,
      snapshot: snapshot,
      post: post,
      postId: row.postId,
      sourceUrl: row.sourceUrl,
    );
  }
  throw const FormatException('Invalid bookmark snapshot');
}

BookmarkHiveObject favoriteToHiveObject(Bookmark bookmark) {
  bookmark.transferIdentity;
  return BookmarkHiveObject(
    booruId: bookmark.booruId,
    createdAt: bookmark.createdAt,
    updatedAt: bookmark.updatedAt,
    thumbnailUrl: bookmark.thumbnailUrl,
    sampleUrl: bookmark.sampleUrl,
    originalUrl: bookmark.originalUrl,
    sourceUrl: bookmark.sourceUrl,
    width: bookmark.width,
    height: bookmark.height,
    md5: bookmark.md5,
    tags: bookmark.tags.toList(),
    realSourceUrl: bookmark.realSourceUrl,
    format: bookmark.format,
    postId: bookmark.postId,
    metadata: bookmark.metadata,
    snapshotSchemaVersion: 2,
    postSnapshot: bookmark.snapshot.toJson(),
  );
}

BookmarkUniqueId bookmarkIdentityForPost(Post post, int booruId) =>
    BookmarkUniqueId.fromPost(post);

extension BookmarkToPost on Bookmark {
  Post toPost() => post;

  PaginationSnapshot? toPaginationSnapshot() => switch (postId) {
    (final postId?) => PaginationSnapshot(
      targetId: postId,
      tags: metadataSearch ?? '',
      historicalPage: metadataPage,
      historicalChunkSize: metadataLimit,
      timestamp: createdAt,
    ),
    _ => null,
  };
}
