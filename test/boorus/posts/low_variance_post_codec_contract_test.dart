// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru/posts/types.dart';
import 'package:boorusama/boorus/gelbooru_v1/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v1/posts/types.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/boorus/hybooru/posts/post_codec.dart';
import 'package:boorusama/boorus/hybooru/posts/types.dart';
import 'package:boorusama/boorus/moebooru/posts/post_codec.dart';
import 'package:boorusama/boorus/moebooru/posts/post_data.dart';
import 'package:boorusama/boorus/moebooru/posts/types.dart';
import 'package:boorusama/boorus/zerochan/posts/post_codec.dart';
import 'package:boorusama/boorus/zerochan/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  final origin = PostOrigin.fromSource(
    booruType: BooruType.gelbooruV1,
    booruId: BooruType.gelbooruV1.id,
    source: 'https://example.com/',
    profileIdHint: 4,
  );

  final emptyCases =
      <
        ({
          String name,
          PostRecord legacy,
          Post Function(PostOrigin origin) convert,
          BooruPostDataCodec<EmptyPostData> codec,
          String typeKey,
        })
      >[
        (
          name: 'Gelbooru V1',
          legacy: _gelbooruV1Post(),
          convert: (origin) => gelbooruV1PostFromRecord(
            _gelbooruV1Post(),
            origin,
          ),
          codec: const GelbooruV1PostCodec(),
          typeKey: 'gelbooru_v1',
        ),
        (
          name: 'Hybooru',
          legacy: _hybooruPost(),
          convert: (origin) => hybooruPostFromRecord(_hybooruPost(), origin),
          codec: const HybooruPostCodec(),
          typeKey: 'hybooru',
        ),
        (
          name: 'Zerochan',
          legacy: _zerochanPost(),
          convert: (origin) => zerochanPostFromRecord(_zerochanPost(), origin),
          codec: const ZerochanPostCodec(),
          typeKey: 'zerochan',
        ),
        (
          name: 'Gelbooru',
          legacy: _gelbooruPost(),
          convert: (origin) => gelbooruPostFromRecord(_gelbooruPost(), origin),
          codec: const GelbooruPostCodec(),
          typeKey: 'gelbooru',
        ),
      ];

  for (final testCase in emptyCases) {
    test('${testCase.name} preserves common fields through a snapshot', () {
      final post = testCase.convert(origin);
      final decoded = _roundTrip(post, testCase.codec);

      _expectCommonPost(decoded, testCase.legacy);
      expect(decoded.origin, origin);
      expect(decoded.booruData, EmptyPostData(typeKey: testCase.typeKey));
    });
  }

  test('Gelbooru V2 preserves its note capability through a snapshot', () {
    final legacy = _gelbooruV2Post();
    final post = gelbooruV2PostFromRecord(legacy, origin);

    final decoded = _roundTrip(post, const GelbooruV2PostCodec());

    _expectCommonPost(decoded, legacy);
    expect(decoded.booruData, const GelbooruV2PostData(hasNotes: true));
  });

  test('Moebooru preserves its large image URL through a snapshot', () {
    final legacy = _moebooruPost();
    final post = moebooruPostFromRecord(legacy, origin);

    final decoded = _roundTrip(post, const MoebooruPostCodec());

    _expectCommonPost(decoded, legacy);
    expect(
      decoded.booruData,
      const MoebooruPostData(largeImageUrl: 'https://cdn.example/large.jpg'),
    );
  });
}

Post _roundTrip<D extends BooruPostData>(
  Post post,
  BooruPostDataCodec<D> dataCodec,
) {
  expect(post.runtimeType, Post);
  const codec = StoredPostCodec();
  final result = codec.decode(
    codec.encode(post, dataCodec: dataCodec),
    dataCodec: dataCodec,
  );
  expect(result, isA<StoredPostDecodeSuccess>());
  final decoded = (result as StoredPostDecodeSuccess).post;
  expect(decoded.runtimeType, Post);
  return decoded;
}

void _expectCommonPost(Post actual, PostRecord expected) {
  expect(actual.id, expected.id);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.thumbnailImageUrl, expected.thumbnailImageUrl);
  expect(actual.sampleImageUrl, expected.sampleImageUrl);
  expect(actual.originalImageUrl, expected.originalImageUrl);
  expect(actual.videoUrl, expected.videoUrl);
  expect(actual.videoThumbnailUrl, expected.videoThumbnailUrl);
  expect(actual.width, expected.width);
  expect(actual.height, expected.height);
  expect(actual.format, expected.format);
  expect(actual.md5, expected.md5);
  expect(actual.fileSize, expected.fileSize);
  expect(actual.duration, expected.duration);
  expect(actual.hasSound, expected.hasSound);
  expect(actual.tags, expected.tags);
  expect(actual.rating, expected.rating);
  expect(actual.hasComment, expected.hasComment);
  expect(actual.isTranslated, expected.isTranslated);
  expect(actual.hasParentOrChildren, expected.hasParentOrChildren);
  expect(actual.parentId, expected.parentId);
  expect(actual.score, expected.score);
  expect(actual.downvotes, expected.downvotes);
  expect(actual.uploaderId, expected.uploaderId);
  expect(actual.uploaderName, expected.uploaderName);
  expect(actual.metadata, expected.metadata);
  expect(actual.status?.matches('active'), expected.status?.matches('active'));
}

GelbooruV1PostRecord _gelbooruV1Post() => GelbooruV1PostRecord(
  id: 11,
  thumbnailImageUrl: 'https://cdn.example/thumb.jpg',
  sampleImageUrl: 'https://cdn.example/sample.jpg',
  originalImageUrl: 'https://cdn.example/original.jpg',
  tags: const {'one', 'two'},
  rating: Rating.questionable,
  hasComment: true,
  isTranslated: true,
  hasParentOrChildren: true,
  source: PostSource.from('https://source.example/work'),
  score: 12,
  duration: 3.5,
  fileSize: 456,
  format: 'jpg',
  hasSound: true,
  height: 800,
  md5: 'hash',
  videoThumbnailUrl: 'https://cdn.example/video-thumb.jpg',
  videoUrl: 'https://cdn.example/video.webm',
  width: 1200,
  uploaderId: 13,
  createdAt: DateTime.utc(2026, 1, 2),
  uploaderName: 'artist',
  metadata: const PostMetadata(page: 2, search: 'one', limit: 40),
);

HybooruPostRecord _hybooruPost() => HybooruPostRecord(
  id: 12,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'hy'},
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 0,
  duration: 0,
  fileSize: 123,
  format: 'png',
  hasSound: null,
  height: 600,
  md5: 'hy-hash',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 900,
  uploaderId: null,
  createdAt: null,
  uploaderName: null,
  metadata: null,
);

ZerochanPostRecord _zerochanPost() => ZerochanPostRecord(
  id: 13,
  thumbnailImageUrl: 'thumb-z',
  sampleImageUrl: 'sample-z',
  originalImageUrl: 'original-z',
  tags: const {'zero'},
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.from('source-z'),
  score: 2,
  duration: kNoduration,
  fileSize: 0,
  format: 'jpg',
  hasSound: null,
  height: 400,
  md5: 'zero-hash',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 300,
  uploaderId: null,
  createdAt: null,
  uploaderName: null,
  metadata: null,
);

GelbooruPostRecord _gelbooruPost() => GelbooruPostRecord(
  format: 'jpg',
  height: 720,
  id: 14,
  md5: 'gel-hash',
  originalImageUrl: 'original-g',
  rating: Rating.explicit,
  sampleImageUrl: 'sample-g',
  source: PostSource.from('https://source.example/g'),
  tags: const {'sound'},
  thumbnailImageUrl: 'thumb-g',
  width: 1280,
  hasComment: true,
  hasParentOrChildren: true,
  fileSize: 999,
  score: 42,
  createdAt: DateTime.utc(2025, 5, 1),
  parentId: 4,
  uploaderId: 5,
  uploaderName: 'gel-user',
  metadata: const PostMetadata(page: 1),
  status: StringPostStatus.tryParse('active'),
);

GelbooruV2PostRecord _gelbooruV2Post() => GelbooruV2PostRecord(
  format: 'png',
  height: 700,
  id: 15,
  md5: 'v2-hash',
  originalImageUrl: 'original-v2',
  rating: Rating.sensitive,
  sampleImageUrl: 'sample-v2',
  source: PostSource.none(),
  tags: const {'translated'},
  thumbnailImageUrl: 'thumb-v2',
  width: 1000,
  hasComment: false,
  hasParentOrChildren: false,
  fileSize: 1,
  score: 3,
  createdAt: null,
  parentId: null,
  uploaderId: null,
  uploaderName: 'owner',
  hasNotes: true,
  metadata: null,
  status: StringPostStatus.tryParse('pending'),
);

MoebooruPostRecord _moebooruPost() => MoebooruPostRecord(
  id: 16,
  tags: const {'moe'},
  source: PostSource.none(),
  thumbnailImageUrl: 'thumb-m',
  sampleImageUrl: 'sample-m',
  largeImageUrl: 'https://cdn.example/large.jpg',
  originalImageUrl: 'original-m',
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: true,
  format: 'jpg',
  width: 1200,
  height: 900,
  md5: 'moe-hash',
  fileSize: 44,
  score: 6,
  createdAt: DateTime.utc(2020),
  parentId: 1,
  uploaderId: 2,
  uploaderName: 'moe-user',
  metadata: const PostMetadata(search: 'moe'),
  status: StringPostStatus.tryParse('active'),
);
