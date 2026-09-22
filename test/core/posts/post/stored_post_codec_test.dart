// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  const codec = StoredPostCodec();
  const dataCodec = _TestPostDataCodec();

  test('round trip preserves every common and custom post value', () {
    final post = UnifiedPost(
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 20,
        source: 'https://danbooru.donmai.us/posts/42',
        profileIdHint: 7,
      ),
      core: PostCoreData(
        id: 42,
        createdAt: DateTime.utc(2026, 9, 22, 10, 30),
        thumbnailImageUrl: 'https://cdn.example/180.jpg',
        sampleImageUrl: 'https://cdn.example/720.jpg',
        originalImageUrl: 'https://cdn.example/original.jpg',
        videoUrl: 'https://cdn.example/video.webm',
        videoThumbnailUrl: 'https://cdn.example/video.jpg',
        mediaVariants: const {
          '180x180': 'https://cdn.example/180.jpg',
          '720x720': 'https://cdn.example/720.jpg',
        },
        thumbnailAspectRatio: 1.25,
        sampleAspectRatio: 1.5,
        originalAspectRatio: 1.75,
        videoThumbnailAspectRatio: 2,
        videoAspectRatio: 2.25,
        width: 1400,
        height: 800,
        format: 'webm',
        md5: '0123456789abcdef',
        fileSize: 123456,
        duration: 12.5,
        hasSound: true,
        tags: const {'sky', 'cloud'},
        artistTags: const {'artist'},
        characterTags: const {'character'},
        copyrightTags: const {'copyright'},
        rating: Rating.questionable,
        hasComment: true,
        isTranslated: true,
        hasParentOrChildren: true,
        parentId: 41,
        source: PostSource.from('https://www.pixiv.net/artworks/123'),
        score: 99,
        downvotes: 4,
        uploaderId: 8,
        uploaderName: 'alice',
        status: 'active',
        metadata: const PostMetadata(page: 3, search: 'sky', limit: 40),
      ),
      booruData: const _TestPostData(label: 'native', count: 5),
    );

    final snapshot = codec.encode(post, dataCodec: dataCodec);
    final json = snapshot.toJson();
    final restoredSnapshot = StoredPostSnapshot.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    final result = codec.decode(restoredSnapshot, dataCodec: dataCodec);

    expect(result, isA<StoredPostDecodeSuccess>());
    final decoded = (result as StoredPostDecodeSuccess).post;
    expect(decoded, post);
    expect(decoded.mediaVariants, post.mediaVariants);
    expect(decoded.effectiveThumbnailAspectRatio, 1.25);
    expect(decoded.effectiveSampleAspectRatio, 1.5);
    expect(decoded.effectiveOriginalAspectRatio, 1.75);
    expect(decoded.effectiveVideoThumbnailAspectRatio, 2);
    expect(decoded.effectiveVideoAspectRatio, 2.25);
    expect(decoded.status?.matches('ACTIVE'), isTrue);
    expect(
      (decoded.source as WebSource).url,
      'https://www.pixiv.net/artworks/123',
    );
  });

  test('absent optional values remain absent and source hosts normalize', () {
    final post = UnifiedPost(
      origin: PostOrigin.fromSource(
        booruType: BooruType.e621,
        booruId: 25,
        source: 'HTTPS://E621.NET:443/posts/1',
      ),
      core: _minimalCore(),
      booruData: const _TestPostData(label: 'minimal', count: 0),
    );

    final result = codec.decode(
      codec.encode(post, dataCodec: dataCodec),
      dataCodec: dataCodec,
    );
    final decoded = (result as StoredPostDecodeSuccess).post;

    expect(decoded.origin.sourceHost, 'e621.net');
    expect(decoded.origin.profileIdHint, isNull);
    expect(decoded.createdAt, isNull);
    expect(decoded.artistTags, isNull);
    expect(decoded.characterTags, isNull);
    expect(decoded.copyrightTags, isNull);
    expect(decoded.downvotes, isNull);
    expect(decoded.parentId, isNull);
    expect(decoded.uploaderId, isNull);
    expect(decoded.uploaderName, isNull);
    expect(decoded.status, isNull);
    expect(decoded.metadata, isNull);
    expect(decoded.hasSound, isNull);
  });

  for (final testCase in [
    (
      name: 'unsupported custom versions',
      snapshot: StoredPostSnapshot(
        origin: _originSnapshot(),
        common: _minimalCommonJson(),
        custom: const {'label': 'future', 'count': 9},
        codecVersion: 99,
      ),
      reason: UnknownPostDataReason.unsupportedVersion,
    ),
    (
      name: 'malformed custom data',
      snapshot: StoredPostSnapshot(
        origin: _originSnapshot(),
        common: _minimalCommonJson(),
        custom: const {'label': 100, 'count': 'invalid'},
        codecVersion: 1,
      ),
      reason: UnknownPostDataReason.malformedData,
    ),
  ]) {
    test('${testCase.name} preserve common data with a generic payload', () {
      final result = codec.decode(testCase.snapshot, dataCodec: dataCodec);

      expect(result, isA<StoredPostDecodeSuccess>());
      final decoded = (result as StoredPostDecodeSuccess).post;
      expect(decoded.id, 1);
      expect(decoded.originalImageUrl, 'https://cdn.example/original.jpg');
      expect(decoded.booruData, isA<UnknownPostData>());
      expect(
        (decoded.booruData as UnknownPostData).reason,
        testCase.reason,
      );
      expect(
        (decoded.booruData as UnknownPostData).custom,
        testCase.snapshot.custom,
      );
    });
  }

  test('malformed common data returns a typed failure', () {
    final result = codec.decode(
      StoredPostSnapshot(
        origin: _originSnapshot(),
        common: {..._minimalCommonJson(), 'id': 'not-an-int'},
        custom: const {'label': 'native', 'count': 1},
        codecVersion: 1,
      ),
      dataCodec: dataCodec,
    );

    expect(result, isA<StoredPostDecodeFailure>());
    expect(
      (result as StoredPostDecodeFailure).reason,
      StoredPostDecodeFailureReason.malformedCommonData,
    );
  });
}

PostCoreData _minimalCore() => PostCoreData(
  id: 1,
  thumbnailImageUrl: 'https://cdn.example/thumbnail.jpg',
  sampleImageUrl: 'https://cdn.example/sample.jpg',
  originalImageUrl: 'https://cdn.example/original.jpg',
  videoUrl: '',
  videoThumbnailUrl: '',
  width: 100,
  height: 200,
  format: 'jpg',
  md5: 'abc',
  fileSize: 300,
  duration: kNoduration,
  tags: const {'tag'},
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 0,
);

PostOriginSnapshot _originSnapshot() => const PostOriginSnapshot(
  booruTypeId: 20,
  booruId: 20,
  sourceHost: 'danbooru.donmai.us',
  profileIdHint: 7,
);

Map<String, Object?> _minimalCommonJson() => const {
  'schemaVersion': 1,
  'id': 1,
  'thumbnailImageUrl': 'https://cdn.example/thumbnail.jpg',
  'sampleImageUrl': 'https://cdn.example/sample.jpg',
  'originalImageUrl': 'https://cdn.example/original.jpg',
  'videoUrl': '',
  'videoThumbnailUrl': '',
  'width': 100.0,
  'height': 200.0,
  'format': 'jpg',
  'md5': 'abc',
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

final class _TestPostData extends Equatable implements BooruPostData {
  const _TestPostData({required this.label, required this.count});

  final String label;
  final int count;

  @override
  String get typeKey => 'test';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [label, count];
}

final class _TestPostDataCodec implements BooruPostDataCodec<_TestPostData> {
  const _TestPostDataCodec();

  @override
  int get currentVersion => 1;

  @override
  String get typeKey => 'test';

  @override
  bool supports(BooruPostData data) => data is _TestPostData;

  @override
  Map<String, Object?> encode(_TestPostData data) => {
    'label': data.label,
    'count': data.count,
  };

  @override
  _TestPostData decode(
    Map<String, Object?> json, {
    required int version,
  }) => switch (json) {
    {'label': final String label, 'count': final int count} => _TestPostData(
      label: label,
      count: count,
    ),
    _ => throw const FormatException('Invalid test post data'),
  };
}
