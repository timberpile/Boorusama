import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/backups/export_import/import/bookmark_profile_dependency.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

const _profile = '00000000-0000-4000-8000-000000000021';

void main() {
  for (final version in [1, 2]) {
    test(
      'profile hint preserves readable v$version unaddressable evidence',
      () {
        final original = _opaquePostBookmark(version);
        final before = original.snapshot;
        expect(original.post.id, 42);
        expect(
          original.snapshot.origin.sourceHost,
          'danbooru.donmai.us/install',
        );
        expect(original.postId, isNull);
        expect(bookmarkContentIdentity(original), isNull);

        final hinted = bookmarkWithProfileHint(original, _profile);
        final hintedRecord = bookmarkRecordWithProfileHint(original, _profile);

        for (final result in [hinted, hintedRecord as PostBookmark]) {
          expect(result.id, original.id);
          expect(result.createdAt, original.createdAt);
          expect(result.updatedAt, original.updatedAt);
          expect(result.postId, isNull);
          expect(result.sourceUrl, original.sourceUrl);
          expect(result.snapshot.codecVersion, version);
          expect(result.snapshot.common, before.common);
          expect(result.snapshot.custom, before.custom);
          expect(result.snapshot.origin.booruTypeId, before.origin.booruTypeId);
          expect(result.snapshot.origin.booruId, before.origin.booruId);
          expect(result.snapshot.origin.sourceHost, before.origin.sourceHost);
          expect(result.snapshot.origin.profileIdHint, _profile);
          expect(result.post.origin.profileIdHint, _profile);
          expect(result.post.id, original.post.id);
          expect(result.post.originalImageUrl, original.post.originalImageUrl);
          expect(result.post.tags, original.post.tags);
          expect(
            result.post.copyWith(origin: original.post.origin),
            original.post,
          );
          expect(bookmarkContentIdentity(result), isNull);
        }
        expect(original.snapshot, before);
        expect(original.snapshot.origin.profileIdHint, isNull);
        expect(original.post.origin.profileIdHint, isNull);
        expect(original.postId, isNull);
        expect(
          hinted.snapshot,
          StoredPostSnapshot(
            origin: PostOriginSnapshot(
              booruTypeId: before.origin.booruTypeId,
              booruId: before.origin.booruId,
              sourceHost: before.origin.sourceHost,
              profileIdHint: _profile,
            ),
            common: before.common,
            custom: before.custom,
            codecVersion: before.codecVersion,
          ),
        );
      },
    );
  }

  test('hint mapping does not reconstruct a flat unaddressable snapshot', () {
    final original = PostBookmark(
      id: 901,
      booruId: BooruType.danbooru.id,
      createdAt: DateTime.utc(2010),
      updatedAt: DateTime.utc(2011),
      thumbnailUrl: 'https://cdn.example/thumb.jpg',
      sampleUrl: 'https://cdn.example/sample.jpg',
      originalUrl: 'https://cdn.example/image.jpg',
      sourceUrl: 'https://source.example/posts/7',
      width: 1,
      height: 2,
      md5: 'flat',
      tags: const {'flat'},
      realSourceUrl: null,
      format: 'jpg',
      imageUrlResolver: const DefaultImageUrlResolver(),
      postId: null,
      metadata: const {},
    );
    final mapped = bookmarkWithProfileHint(original, _profile);
    expect(mapped.postId, isNull);
    expect(bookmarkContentIdentity(mapped), isNull);
    expect(mapped.snapshot.common, original.snapshot.common);
    expect(mapped.snapshot.custom, original.snapshot.custom);
    expect(mapped.snapshot.codecVersion, original.snapshot.codecVersion);
    expect(mapped.sourceUrl, original.sourceUrl);
  });

  test('stable profile mapping preserves its established identity', () {
    final original = _stablePostBookmark();
    final mapped = bookmarkWithProfileHint(original, _profile);
    expect(mapped.postId, original.postId);
    expect(bookmarkContentIdentity(mapped), bookmarkContentIdentity(original));
    expect(mapped.snapshot.common, original.snapshot.common);
    expect(mapped.snapshot.custom, original.snapshot.custom);
    expect(mapped.sourceUrl, original.sourceUrl);
  });

  test('v10 codec normalizes the hint and preserves null outer Post ID', () {
    final original = _opaquePostBookmark(2);
    final hinted = bookmarkWithProfileHint(original, _profile);
    final codec = BookmarkBackupCodec();
    final data = BookmarkBackupData.unified(
      records: [hinted],
      groups: const [],
    );
    final payload = encodeData(
      version: 10,
      exportDate: DateTime.utc(2026, 1, 1),
      exportVersion: null,
      payload: codec.encode(data),
      extraFields: data.extraFields,
    );
    final normalized = const StoredBookmarkCodec().decode(
      const StoredBookmarkCodec().encode(hinted),
    ) as PostBookmark;
    expect(normalized.postId, isNull);
    expect(bookmarkContentIdentity(normalized), isNull);
    final decoded =
        codec.parse(decodeData(data: payload)).records.single as PostBookmark;

    expect(decoded.postId, isNull);
    expect(decoded.snapshot.origin.profileIdHint, _profile);
    expect(decoded.post.origin.profileIdHint, _profile);
    expect(decoded.snapshot.codecVersion, 2);
    expect(decoded.snapshot.common, original.snapshot.common);
    expect(decoded.snapshot.custom, original.snapshot.custom);
    expect(
      decoded.snapshot.origin.sourceHost,
      original.snapshot.origin.sourceHost,
    );
    expect(bookmarkContentIdentity(decoded), isNull);
    expect(bookmarkContentIdentity(_stablePostBookmark()), isNotNull);
  });
}

PostBookmark _opaquePostBookmark(int version) {
  // Both custom-payload versions retain a supported common schema. A known
  // namespace and positive decoded number do not prove the outer upstream ID.
  final common = <String, Object?>{
    'schemaVersion': 1,
    'id': 42,
    'thumbnailImageUrl': 'https://cdn.example/thumb.jpg',
    'sampleImageUrl': 'https://cdn.example/sample.jpg',
    'originalImageUrl': 'https://cdn.example/original.jpg',
    'videoUrl': '',
    'videoThumbnailUrl': '',
    'width': 100.0,
    'height': 200.0,
    'format': 'jpg',
    'md5': 'opaque-md5',
    'fileSize': 300,
    'duration': -1.0,
    'tags': ['tag'],
    'rating': 'general',
    'hasComment': false,
    'isTranslated': false,
    'hasParentOrChildren': false,
    'source': {'kind': 'none'},
    'score': 0,
  };
  final snapshot = StoredPostSnapshot(
    origin: PostOriginSnapshot(
      booruTypeId: BooruType.danbooru.id,
      booruId: BooruType.danbooru.id,
      sourceHost: 'danbooru.donmai.us/install',
      profileIdHint: null,
    ),
    common: common,
    custom: const {'typeKey': 'unsupported.retained', 'futureField': 'kept'},
    codecVersion: version,
  );
  final decoded = const StoredPostCodec().decode(snapshot);
  final post = (decoded as StoredPostDecodeSuccess).post;
  return PostBookmark.fromSnapshot(
    id: 701,
    createdAt: DateTime.utc(2020, 1, 2, 3, 4, 5, 123, 456),
    updatedAt: DateTime.utc(2025, 6, 7, 8, 9, 10, 789, 123),
    snapshot: snapshot,
    post: version == 1
        ? post.copyWith(
            origin: PostOrigin.fromSource(
              booruType: post.origin.booruType,
              booruId: post.origin.booruId,
              source: '',
            ),
          )
        : post,
    postId: null,
    sourceUrl: 'https://local.example/retained-source',
  );
}

PostBookmark _stablePostBookmark() {
  final unaddressable = _opaquePostBookmark(2);
  return PostBookmark.fromSnapshot(
    id: 702,
    createdAt: unaddressable.createdAt,
    updatedAt: unaddressable.updatedAt,
    snapshot: unaddressable.snapshot,
    post: unaddressable.post,
    postId: unaddressable.post.id,
  );
}
