import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feed rows round-trip complete native post snapshots', () {
    final post = _post(const GelbooruV2PostData(hasNotes: true));
    final row = CachedFeedPost.fromPost(
      post,
      dataCodec: const GelbooruV2PostCodec(),
    );

    final restored = CachedFeedPost.fromJson(
      row.toJson(),
      dataCodec: const GelbooruV2PostCodec(),
    );

    expect(restored.snapshot, row.snapshot);
    expect(restored.post, post);
    expect(restored.toJson(), {
      'snapshotSchemaVersion': 1,
      'postSnapshot': row.snapshot.toJson(),
    });
  });

  test('legacy feed rows migrate to a generic full snapshot', () {
    final row = CachedFeedPost.fromJson({
      'id': 42,
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'thumbnail': 'thumb',
      'sample': 'sample',
      'original': 'original',
      'tags': const ['cat'],
      'rating': 'general',
      'width': 100,
      'height': 200,
      'format': 'jpg',
      'mediaVariants': const {'180x180': 'small'},
    }, profileId: 17);

    expect(row.id, 42);
    expect(row.post.origin.booruType, BooruType.unknown);
    expect(row.post.origin.profileIdHint, 17);
    expect(row.post.booruData, isA<LegacyPostData>());
    expect(row.post.mediaVariants, {'180x180': 'small'});
    expect(row.toJson().keys, {'snapshotSchemaVersion', 'postSnapshot'});
  });

  test('unsupported custom data keeps cached media in generic UI', () {
    final native = CachedFeedPost.fromPost(
      _post(const GelbooruV2PostData(hasNotes: true)),
      dataCodec: const GelbooruV2PostCodec(),
    );
    final malformed = CachedFeedPost.fromJson({
      'snapshotSchemaVersion': 1,
      'postSnapshot': {
        ...native.snapshot.toJson(),
        'codecVersion': 99,
        'custom': const {'future': true},
      },
    }, dataCodec: const GelbooruV2PostCodec());

    expect(malformed.post.booruData, isA<UnknownPostData>());
    expect(malformed.post.sampleImageUrl, 'sample');
    expect(malformed.post.id, 42);
  });
}

UnifiedPost _post(BooruPostData data) => UnifiedPost(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: 23,
    source: 'https://gelbooru.example',
    profileIdHint: 17,
  ),
  core: PostCoreData(
    id: 42,
    createdAt: DateTime.utc(2026),
    thumbnailImageUrl: 'thumb',
    sampleImageUrl: 'sample',
    originalImageUrl: 'original',
    videoUrl: '',
    videoThumbnailUrl: '',
    mediaVariants: const {'180x180': 'small'},
    width: 100,
    height: 200,
    format: 'jpg',
    md5: 'md5',
    fileSize: 12,
    duration: 0,
    tags: const {'cat'},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 3,
  ),
  booruData: data,
);
