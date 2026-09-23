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
    final snapshot = feedPostSnapshotFromPost(
      post,
      dataCodec: const GelbooruV2PostCodec(),
    );

    final restoredSnapshot = feedPostSnapshotFromJson(
      feedPostSnapshotToJson(snapshot),
    );
    final restored = decodeFeedPost(
      restoredSnapshot,
      dataCodec: const GelbooruV2PostCodec(),
    );

    expect(restoredSnapshot, snapshot);
    expect(restored, post);
    expect(feedPostSnapshotToJson(restoredSnapshot), {
      'snapshotSchemaVersion': 1,
      'postSnapshot': snapshot.toJson(),
    });
  });

  test('legacy feed rows migrate to a generic full snapshot', () {
    final snapshot = feedPostSnapshotFromJson({
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

    final post = decodeFeedPost(snapshot);
    expect(feedPostId(snapshot), 42);
    expect(post.origin.booruType, BooruType.unknown);
    expect(post.origin.profileIdHint, 17);
    expect(post.booruData, isA<LegacyPostData>());
    expect(post.mediaVariants, {'180x180': 'small'});
    expect(feedPostSnapshotToJson(snapshot).keys, {
      'snapshotSchemaVersion',
      'postSnapshot',
    });
  });

  test('unsupported custom data keeps cached media in generic UI', () {
    final native = feedPostSnapshotFromPost(
      _post(const GelbooruV2PostData(hasNotes: true)),
      dataCodec: const GelbooruV2PostCodec(),
    );
    final malformedSnapshot = feedPostSnapshotFromJson({
      'snapshotSchemaVersion': 1,
      'postSnapshot': {
        ...native.toJson(),
        'codecVersion': 99,
        'custom': const {'future': true},
      },
    });
    final malformed = decodeFeedPost(
      malformedSnapshot,
      dataCodec: const GelbooruV2PostCodec(),
    );

    expect(malformed.booruData, isA<UnknownPostData>());
    expect(malformed.sampleImageUrl, 'sample');
    expect(malformed.id, 42);
  });
}

Post _post(BooruPostData data) => Post(
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
