import 'package:foundation/performance.dart';

// Package imports:
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../foundation/loggers/logger.dart';
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

Either<BookmarkGetError, List<PostBookmark>>
tryMapBookmarkHiveObjectsToBookmarks(
  Iterable<BookmarkHiveObject> hiveObjects,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
  Logger? logger,
]) => Either.tryCatch(
  () => performanceRecorder.measureSync(
    PerfOperation.bookmarkDecodeAll,
    () => hiveObjects
        .map((row) => _mapBookmark(row, postDataCodec, logger))
        .toList(),
  ),
  (_, _) => BookmarkGetError.nullField,
);

Either<BookmarkGetError, PostBookmark> tryMapBookmarkHiveObjectToBookmark(
  BookmarkHiveObject hiveObject,
  ImageUrlResolver Function(int? booruId) imageUrlResolver, [
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
  Logger? logger,
]) => Either.tryCatch(
  () => _mapBookmark(hiveObject, postDataCodec, logger),
  (_, _) => BookmarkGetError.nullField,
);

PostBookmark _mapBookmark(
  BookmarkHiveObject row,
  BooruPostDataCodec? Function(BooruType type)? postDataCodec,
  Logger? logger,
) {
  final version = row.snapshotSchemaVersion;
  if (version != null && version != 1 && version != 2) {
    throw const FormatException('Unsupported bookmark row');
  }
  if (row.createdAt == null || row.updatedAt == null) {
    throw const FormatException('Missing bookmark dates');
  }
  if (row.postSnapshot == null) {
    if (version == 2) throw const FormatException('Missing Post snapshot');
    // Old flat rows did not prove an installation locator. Retain their media
    // and original source URL, without treating a page URL/local ID as identity.
    final view = PostBookmark(
      id: -1,
      booruId: row.booruId ?? BooruType.unknown.id,
      createdAt: row.createdAt!,
      updatedAt: row.updatedAt!,
      thumbnailUrl: row.thumbnailUrl ?? '',
      sampleUrl: row.sampleUrl ?? '',
      originalUrl: row.originalUrl ?? '',
      sourceUrl: '',
      width: row.width ?? 0,
      height: row.height ?? 0,
      md5: row.md5 ?? '',
      tags: row.tags?.toSet() ?? const {},
      realSourceUrl: row.realSourceUrl,
      format: row.format,
      imageUrlResolver: const DefaultImageUrlResolver(),
      postId: row.postId,
      metadata: row.metadata ?? const {},
    );
    return PostBookmark.fromSnapshot(
      id: row.key,
      createdAt: view.createdAt,
      updatedAt: view.updatedAt,
      snapshot: view.snapshot,
      post: view.post,
      postId: null,
      sourceUrl: row.sourceUrl,
    );
  }
  final snapshot = StoredPostSnapshot.fromJson(
    Map<String, dynamic>.from(row.postSnapshot!),
  );
  final type = BooruType.fromLegacyId(snapshot.origin.booruTypeId);
  final decoded = StoredPostCodec(logger: logger).decode(
    snapshot,
    dataCodec: postDataCodec?.call(type),
  );
  if (decoded case StoredPostDecodeSuccess(:final post)) {
    // Keep readable legacy media without inventing an upstream identity.
    // Unprovable identities stay out of deduplication; new writes stay strict.
    if ((row.postId != null && row.postId != post.id) ||
        row.createdAt == null ||
        row.updatedAt == null) {
      throw const FormatException('Invalid bookmark snapshot identity');
    }
    final identityProven = version == 2 && row.postId != null;
    return PostBookmark.fromSnapshot(
      id: row.key,
      createdAt: row.createdAt!,
      updatedAt: row.updatedAt!,
      snapshot: snapshot,
      post: identityProven
          ? post
          : post.copyWith(
              origin: PostOrigin.fromSource(
                booruType: post.origin.booruType,
                booruId: post.origin.booruId,
                source: '',
                profileIdHint: post.origin.profileIdHint,
              ),
            ),
      postId: identityProven ? row.postId : null,
      sourceUrl: row.sourceUrl,
    );
  }
  throw const FormatException('Invalid bookmark snapshot');
}

BookmarkHiveObject favoriteToHiveObject(PostBookmark bookmark) {
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

extension BookmarkToPost on PostBookmark {
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
