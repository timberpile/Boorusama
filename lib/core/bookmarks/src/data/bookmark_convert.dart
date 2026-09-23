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

Post recoverBookmarkPostOrigin(Post post, String? sourceUrl) {
  if (post.origin.sourceHost.isNotEmpty || sourceUrl == null) return post;

  return post.copyWith(
    origin: PostOrigin.fromSource(
      booruType: post.origin.booruType,
      booruId: post.origin.booruId,
      source: sourceUrl,
      profileIdHint: post.origin.profileIdHint,
    ),
  );
}

Either<BookmarkGetError, List<Bookmark>> tryMapBookmarkHiveObjectsToBookmarks(
  Iterable<BookmarkHiveObject> hiveObjects,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
]) => Either.tryCatch(
  () => hiveObjects
      .map(
        (hiveObject) => _mapBookmark(
          hiveObject,
          imageUrlResolver,
          postDataCodec,
        ).bookmark,
      )
      .toList(),
  (o, s) {
    return BookmarkGetError.nullField;
  },
);

Either<BookmarkGetError, Bookmark> tryMapBookmarkHiveObjectToBookmark(
  BookmarkHiveObject hiveObject,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
]) => Either.tryCatch(
  () => _mapBookmark(
    hiveObject,
    imageUrlResolver,
    postDataCodec,
  ).bookmark,
  (o, s) => BookmarkGetError.nullField,
);

typedef BookmarkHiveMapping = ({
  Bookmark bookmark,
  bool needsWriteBack,
});

Either<BookmarkGetError, List<BookmarkHiveMapping>>
tryMapBookmarkHiveObjectsWithWriteBack(
  Iterable<BookmarkHiveObject> hiveObjects,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
]) => Either.tryCatch(
  () => hiveObjects
      .map(
        (hiveObject) => _mapBookmark(
          hiveObject,
          imageUrlResolver,
          postDataCodec,
        ),
      )
      .toList(),
  (o, s) => BookmarkGetError.nullField,
);

BookmarkHiveMapping _mapBookmark(
  BookmarkHiveObject hiveObject,
  ImageUrlResolver Function(int? booruId) imageUrlResolver,
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
) {
  final fallback = Bookmark(
    id: hiveObject.key,
    booruId: hiveObject.booruId!,
    createdAt: hiveObject.createdAt!,
    updatedAt: hiveObject.updatedAt!,
    thumbnailUrl: hiveObject.thumbnailUrl!,
    sampleUrl: hiveObject.sampleUrl!,
    originalUrl: hiveObject.originalUrl!,
    sourceUrl: hiveObject.sourceUrl!,
    width: hiveObject.width!,
    height: hiveObject.height!,
    md5: hiveObject.md5!,
    tags: hiveObject.tags?.toSet() ?? {},
    realSourceUrl: hiveObject.realSourceUrl,
    format: hiveObject.format,
    imageUrlResolver: imageUrlResolver(hiveObject.booruId),
    postId: hiveObject.postId,
    metadata: hiveObject.metadata ?? {},
  );
  if (hiveObject.snapshotSchemaVersion == null &&
      hiveObject.postSnapshot == null) {
    return (bookmark: fallback, needsWriteBack: true);
  }
  if (hiveObject.snapshotSchemaVersion != 1 ||
      hiveObject.postSnapshot == null) {
    return (bookmark: fallback, needsWriteBack: false);
  }

  try {
    final snapshot = StoredPostSnapshot.fromJson(
      Map<String, dynamic>.from(hiveObject.postSnapshot!),
    );
    final type = BooruType.fromLegacyId(snapshot.origin.booruTypeId);
    final result = const StoredPostCodec().decode(
      snapshot,
      dataCodec: postDataCodec?.call(type),
    );
    return switch (result) {
      StoredPostDecodeSuccess(:final post) => _bookmarkFromStoredSnapshot(
        hiveObject,
        snapshot,
        post,
      ),
      StoredPostDecodeFailure() => (
        bookmark: fallback,
        needsWriteBack: false,
      ),
    };
  } catch (_) {
    return (bookmark: fallback, needsWriteBack: false);
  }
}

BookmarkHiveMapping _bookmarkFromStoredSnapshot(
  BookmarkHiveObject hiveObject,
  StoredPostSnapshot snapshot,
  Post post,
) {
  final recoveredPost = recoverBookmarkPostOrigin(post, hiveObject.sourceUrl);
  final originWasRecovered = recoveredPost != post;
  final recoveredSnapshot = !originWasRecovered
      ? snapshot
      : StoredPostSnapshot(
          origin: recoveredPost.origin.toSnapshot(),
          common: snapshot.common,
          custom: snapshot.custom,
          codecVersion: snapshot.codecVersion,
        );

  return (
    bookmark: Bookmark.fromSnapshot(
      id: hiveObject.key,
      createdAt: hiveObject.createdAt!,
      updatedAt: hiveObject.updatedAt!,
      snapshot: recoveredSnapshot,
      post: recoveredPost,
      postId: hiveObject.postId,
      sourceUrl: hiveObject.sourceUrl,
    ),
    needsWriteBack: originWasRecovered,
  );
}

BookmarkHiveObject favoriteToHiveObject(Bookmark bookmark) {
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
    snapshotSchemaVersion: 1,
    postSnapshot: bookmark.snapshot.toJson(),
  );
}

BookmarkUniqueId bookmarkIdentityForPost(Post post, int booruId) =>
    BookmarkUniqueId.fromPost(post, post.origin.booruType.id);

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
