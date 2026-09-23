// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  final bookmark = Bookmark.empty.copyWith(
    id: 12,
    originalUrl: 'https://example.com/12.jpg',
  );
  final codec = BookmarkBackupCodec(
    bookmarkParser: (json) => Bookmark.fromJson(
      json,
      imageUrlResolver: const DefaultImageUrlResolver(),
    ),
    postDataCodec: (type) => switch (type) {
      BooruType.gelbooruV2 => const GelbooruV2PostCodec(),
      _ => null,
    },
  );

  test('version 2 preserves the complete snapshot and group references', () {
    final post = _nativePost();
    final snapshot = const StoredPostCodec().encode(
      post,
      dataCodec: const GelbooruV2PostCodec(),
    );
    final nativeBookmark = Bookmark.fromSnapshot(
      id: 12,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 2, 3),
      snapshot: snapshot,
      post: post,
      postId: post.id,
    );
    final data = BookmarkBackupData(
      bookmarks: [nativeBookmark],
      groups: const [
        BookmarkGroupBackup(
          id: groupId,
          name: 'Native',
          bookmarkIds: [12],
        ),
      ],
    );

    final encoded = codec.encode(data);
    expect(encoded, [
      {
        'localId': 12,
        'createdAt': '2026-01-02T00:00:00.000Z',
        'updatedAt': '2026-02-03T00:00:00.000Z',
        'snapshot': snapshot.toJson(),
        'postId': 42,
      },
    ]);

    final restored = codec.parse(
      decodeData(
        data: jsonEncode({
          'version': 2,
          'data': encoded,
          ...data.extraFields,
        }),
      ),
    );

    expect(restored.bookmarks.single, nativeBookmark);
    expect(restored.bookmarks.single.post, post);
    expect(restored.groups, data.groups);
  });

  test('version 2 preserves an explicit null legacy post identity', () {
    final legacyBookmark = _legacyBookmark(postId: null);
    final encoded = codec.encode(
      BookmarkBackupData(bookmarks: [legacyBookmark], groups: const []),
    );

    expect(encoded.single, containsPair('postId', null));

    final restored = codec.parse(
      decodeData(
        data: jsonEncode({'version': 2, 'data': encoded}),
      ),
    );

    expect(restored.bookmarks.single.postId, isNull);
  });

  test('old version 2 legacy snapshots have no trusted post identity', () {
    final legacyBookmark = _legacyBookmark(postId: null);

    final restored = codec.parse(
      _version2Payload(_version2Row(legacyBookmark)),
    );

    expect(restored.bookmarks.single.postId, isNull);
  });

  test('old version 2 native snapshots retain their post identity', () {
    final post = _nativePost();
    final nativeBookmark = Bookmark.fromSnapshot(
      id: 12,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 2, 3),
      snapshot: const StoredPostCodec().encode(
        post,
        dataCodec: const GelbooruV2PostCodec(),
      ),
      post: post,
      postId: post.id,
    );

    final restored = codec.parse(
      _version2Payload(_version2Row(nativeBookmark)),
    );

    expect(restored.bookmarks.single.postId, 42);
  });

  test('old version 2 unknown snapshots have no trusted post identity', () {
    final legacyBookmark = _legacyBookmark(postId: null);
    final row = _version2Row(legacyBookmark);
    row['snapshot'] = {
      ...legacyBookmark.snapshot.toJson(),
      'codecVersion': 99,
      'custom': const {'future': true},
    };

    final restored = codec.parse(_version2Payload(row));

    expect(restored.bookmarks.single.post.booruData, isA<UnknownPostData>());
    expect(restored.bookmarks.single.postId, isNull);
  });

  for (final malformedPostId in ['42', 42.0, false, <String, Object?>{}]) {
    test('rejects version 2 post identity represented by $malformedPostId', () {
      final row = _version2Row(_legacyBookmark(postId: null));
      row['postId'] = malformedPostId;

      expect(
        () => codec.parse(_version2Payload(row)),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }

  test('version 1 imports only legacy fields without invented native data', () {
    final restored = codec.parse(
      decodeData(
        data: jsonEncode({
          'version': 1,
          'data': [bookmark.toJson()],
        }),
      ),
    );

    final imported = restored.bookmarks.single;
    expect(imported.post.booruData, isA<LegacyPostData>());
    expect(imported.snapshot.custom, isEmpty);
  });

  test('imports the legacy group shape without an ID', () {
    final payload = decodeData(
      data: jsonEncode({
        'version': 1,
        'data': [bookmark.toJson()],
        'groups': [
          {
            'name': 'Shared',
            'bookmarkIds': [12],
          },
        ],
      }),
    );

    final data = codec.parse(payload);

    expect(data.groups.single.id, isNull);
    expect(data.groups.single.name, 'Shared');
    expect(data.groups.single.bookmarkIds, [12]);
  });

  test('preserves and emits a canonical group ID', () {
    final payload = decodeData(
      data: jsonEncode({
        'version': 1,
        'data': [bookmark.toJson()],
        'groups': [
          {
            'id': groupId.toUpperCase(),
            'name': 'Shared',
            'bookmarkIds': [12, 12],
          },
        ],
      }),
    );

    final data = codec.parse(payload);

    expect(data.groups.single.id, groupId);
    expect(data.groups.single.bookmarkIds, [12]);
    expect(data.extraFields['groups'], [
      {
        'id': groupId,
        'name': 'Shared',
        'bookmarkIds': [12],
      },
    ]);
  });

  for (final groups in [
    [
      {'id': 'bad', 'name': 'Shared', 'bookmarkIds': <int>[]},
    ],
    [
      {'id': groupId, 'name': 'One', 'bookmarkIds': <int>[]},
      {'id': groupId, 'name': 'Two', 'bookmarkIds': <int>[]},
    ],
  ]) {
    test('rejects malformed or repeated supplied group IDs', () {
      final payload = decodeData(
        data: jsonEncode({'version': 1, 'data': [], 'groups': groups}),
      );
      expect(
        () => codec.parse(payload),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }

  final duplicateBookmarkCases = [
    (
      description: 'file-local bookmark IDs',
      bookmarks: [
        bookmark,
        bookmark.copyWith(originalUrl: 'https://example.com/other.jpg'),
      ],
    ),
    (
      description: 'bookmark identities',
      bookmarks: [bookmark, bookmark.copyWith(id: 13)],
    ),
  ];
  for (final testCase in duplicateBookmarkCases) {
    test('rejects duplicate ${testCase.description}', () {
      final payload = decodeData(
        data: jsonEncode({
          'version': 1,
          'data': testCase.bookmarks.map((item) => item.toJson()).toList(),
        }),
      );

      expect(
        () => codec.parse(payload),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }

  for (final tags in [
    123,
    [1, 'tag'],
    '{"tag": true}',
  ]) {
    test('rejects malformed bookmark tags represented by $tags', () {
      final malformed = bookmark.toJson()..['tags'] = tags;
      final payload = decodeData(
        data: jsonEncode({
          'version': 1,
          'data': [malformed],
        }),
      );

      expect(
        () => codec.parse(payload),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  }

  test('accepts the legacy JSON-string tag representation', () {
    final legacy = bookmark.toJson()..['tags'] = '["one", "two"]';
    final payload = decodeData(
      data: jsonEncode({
        'version': 1,
        'data': [legacy],
      }),
    );

    expect(codec.parse(payload).bookmarks.single.tags, {'one', 'two'});
  });

  test('rejects an explicit null groups field', () {
    final payload = decodeData(
      data: jsonEncode({
        'version': 1,
        'data': [bookmark.toJson()],
        'groups': null,
      }),
    );

    expect(
      () => codec.parse(payload),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });
}

Post _nativePost() => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: BooruType.gelbooruV2.id,
    source: 'https://gelbooru.example',
    profileIdHint: 17,
  ),
  core: PostCoreData(
    id: 42,
    createdAt: DateTime.utc(2025, 12, 31),
    thumbnailImageUrl: 'https://img.example/thumbnail.jpg',
    sampleImageUrl: 'https://img.example/sample.jpg',
    originalImageUrl: 'https://img.example/original.jpg',
    videoUrl: '',
    videoThumbnailUrl: '',
    mediaVariants: const {'180x180': 'https://img.example/180.jpg'},
    width: 100,
    height: 200,
    format: 'jpg',
    md5: 'native-md5',
    fileSize: 123,
    duration: 0,
    tags: const {'cat', 'blue_eyes'},
    artistTags: const {'artist'},
    rating: Rating.general,
    hasComment: true,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.from('https://source.example/work'),
    score: 9,
  ),
  booruData: const GelbooruV2PostData(hasNotes: true),
);

Bookmark _legacyBookmark({required int? postId}) => Bookmark(
  id: 501,
  booruId: BooruType.gelbooruV2.id,
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025, 1, 2),
  thumbnailUrl: 'thumbnail-91',
  sampleUrl: 'sample-91',
  originalUrl: 'original-91',
  sourceUrl: 'https://gelbooru.example/posts/91',
  width: 100,
  height: 100,
  md5: 'legacy-91',
  tags: const {'cached'},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: postId,
  metadata: const {},
);

Map<String, dynamic> _version2Row(Bookmark bookmark) => {
  'localId': bookmark.localId,
  'createdAt': bookmark.createdAt.toIso8601String(),
  'updatedAt': bookmark.updatedAt.toIso8601String(),
  'snapshot': bookmark.snapshot.toJson(),
};

ExportDataPayload _version2Payload(Map<String, dynamic> row) => decodeData(
  data: jsonEncode({
    'version': 2,
    'data': [row],
  }),
);
