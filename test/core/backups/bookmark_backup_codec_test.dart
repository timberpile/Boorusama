// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import '../../profile_uuid_utils.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  final codec = BookmarkBackupCodec(
    postDataCodec: (type) => switch (type) {
      BooruType.gelbooruV2 => const GelbooruV2PostCodec(),
      _ => null,
    },
  );

  test('version 4 round trips the complete snapshot, identity and group', () {
    final bookmark = _nativeBookmark(localId: 12);
    final data = BookmarkBackupData(
      bookmarks: [bookmark],
      groups: const [
        BookmarkGroupBackup(id: groupId, name: 'Native', bookmarkIds: [12]),
      ],
    );
    final encoded = codec.encode(data);

    expect(encoded, [
      {
        'localId': 12,
        'createdAt': '2026-01-02T00:00:00.000Z',
        'updatedAt': '2026-02-03T00:00:00.000Z',
        'snapshot': bookmark.snapshot.toJson(),
        'postId': 42,
        'identity': {'site': 'gelbooru.example/board', 'postKey': 'id:42'},
      },
    ]);
    final restored = codec.parse(
      decodeData(
        data: jsonEncode({
          'version': 4,
          'data': encoded,
          ...data.extraFields,
        }),
      ),
    );

    expect(restored.bookmarks.single, bookmark);
    expect(restored.groups, data.groups);
  });

  test('rejects group references to bookmarks absent from the package', () {
    final row = _row(codec, _nativeBookmark(localId: 12));
    final payload = decodeData(
      data: jsonEncode({
        'version': 4,
        'data': [row],
        'groups': [
          {
            'id': groupId,
            'name': 'Shared',
            'bookmarkIds': [12, 999],
          },
        ],
      }),
    );

    expect(
      () => codec.parse(payload),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects an identity that differs from the decoded snapshot', () {
    final row = _row(codec, _nativeBookmark(localId: 12));
    row['identity'] = {'site': 'other.example', 'postKey': 'id:42'};

    expect(
      () => codec.parse(_payload([row])),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects an upstream key that differs from the decoded snapshot', () {
    final row = _row(codec, _nativeBookmark(localId: 12));
    row['identity'] = {
      'site': 'gelbooru.example/board',
      'postKey': 'id:43',
    };

    expect(
      () => codec.parse(_payload([row])),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects older bookmark source versions before import', () {
    expect(
      () => codec.parse(
        decodeData(data: jsonEncode({'version': 3, 'data': []})),
      ),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects an omitted portable identity', () {
    final row = _row(codec, _nativeBookmark(localId: 12))..remove('identity');

    expect(
      () => codec.parse(_payload([row])),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects repeated upstream identities despite different local IDs', () {
    final first = _nativeBookmark(localId: 12);
    final second = first.copyWith(id: 13);

    expect(
      () => codec.parse(_payload([_row(codec, first), _row(codec, second)])),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects repeated file-local row IDs despite different posts', () {
    final first = _nativeBookmark(localId: 12);
    final second = _nativeBookmark(localId: 12, postId: 43);

    expect(
      () => codec.parse(_payload([_row(codec, first), _row(codec, second)])),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('rejects an export row without a trusted upstream post ID', () {
    final legacy = Bookmark(
      id: 501,
      booruId: BooruType.gelbooruV2.id,
      createdAt: DateTime.utc(2025),
      updatedAt: DateTime.utc(2025, 1, 2),
      thumbnailUrl: 'thumbnail',
      sampleUrl: 'sample',
      originalUrl: 'original',
      sourceUrl: 'https://gelbooru.example/board',
      width: 100,
      height: 100,
      md5: 'md5',
      tags: const {},
      realSourceUrl: null,
      format: 'jpg',
      imageUrlResolver: const DefaultImageUrlResolver(),
      postId: null,
      metadata: const {},
    );

    expect(
      () => codec.encode(
        BookmarkBackupData(bookmarks: [legacy], groups: const []),
      ),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('preserves and validates a canonical group UUID', () {
    final row = _row(codec, _nativeBookmark(localId: 12));
    final data = codec.parse(
      decodeData(
        data: jsonEncode({
          'version': 4,
          'data': [row],
          'groups': [
            {
              'id': groupId.toUpperCase(),
              'name': 'Shared',
              'bookmarkIds': [12, 12],
            },
          ],
        }),
      ),
    );
    expect(data.groups.single.id, groupId);
    expect(data.groups.single.bookmarkIds, [12]);

    expect(
      () => codec.parse(
        decodeData(
          data: jsonEncode({
            'version': 4,
            'data': [],
            'groups': [
              {'id': 'bad', 'name': 'Shared', 'bookmarkIds': <int>[]},
            ],
          }),
        ),
      ),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });
}

Map<String, dynamic> _row(BookmarkBackupCodec codec, Bookmark bookmark) =>
    codec
            .encode(
              BookmarkBackupData(bookmarks: [bookmark], groups: const []),
            )
            .single
        as Map<String, dynamic>;

ExportDataPayload _payload(List<Map<String, dynamic>> rows) =>
    decodeData(data: jsonEncode({'version': 4, 'data': rows}));

Bookmark _nativeBookmark({required int localId, int postId = 42}) {
  final post = Post(
    origin: PostOrigin.fromSource(
      booruType: BooruType.gelbooruV2,
      booruId: BooruType.gelbooruV2.id,
      source: 'https://gelbooru.example/board/',
      profileIdHint: profileUuid(17),
    ),
    core: PostCoreData(
      id: postId,
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
  return Bookmark.fromSnapshot(
    id: localId,
    createdAt: DateTime.utc(2026, 1, 2),
    updatedAt: DateTime.utc(2026, 2, 3),
    snapshot: const StoredPostCodec().encode(
      post,
      dataCodec: const GelbooruV2PostCodec(),
    ),
    post: post,
    postId: post.id,
  );
}
