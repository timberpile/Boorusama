import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'feed merge distinguishes sites but deduplicates profiles on one site',
    () {
      final post = _post(const GelbooruV2PostData(hasNotes: true));
      StoredPostSnapshot snapshot(String host, String profile) =>
          feedPostSnapshotFromPost(
            post,
            origin: PostOrigin.fromSource(
              booruType: BooruType.gelbooruV2,
              booruId: 23,
              source: 'https://$host',
              profileIdHint: profile,
            ),
            dataCodec: const GelbooruV2PostCodec(),
          );
      final profiles = [
        '00000000-0000-4000-8000-000000000011',
        '00000000-0000-4000-8000-000000000012',
      ];
      final feed =
          TopicFeed(
            id: 'mixed',
            name: 'Cross-site',
            profileId: profiles.first,
          ).merge([
            snapshot('gelbooru.example', profiles.first),
            snapshot('gelbooru.example', profiles.last),
            snapshot('another.example', profiles.first),
          ]);

      expect(feed.posts.length, 2);
      expect(feed.posts.map(feedPostId).toSet(), {42});
      expect(feed.posts.map(feedPostIdentity).toSet().length, 2);
    },
  );

  test('legacy feed metadata retains cached posts with the new default', () {
    final snapshot = feedPostSnapshotFromPost(
      _post(const GelbooruV2PostData(hasNotes: true)),
      dataCodec: const GelbooruV2PostCodec(),
    );
    final feed = TopicFeed(
      id: 'feed',
      profileId: '00000000-0000-4000-8000-000000000011',
      name: 'Original feed',
      posts: [snapshot],
    );
    final legacy = Map<String, Object?>.from(feed.toJson())..remove('maxPosts');

    final restored = TopicFeed.fromJson(legacy);

    expect(restored.maxPosts, 1000);
    expect(restored.posts, [snapshot]);
  });

  test(
    'custom retention persists and does not discard a large refresh page',
    () {
      final base = feedPostSnapshotFromPost(
        _post(const GelbooruV2PostData(hasNotes: true)),
        dataCodec: const GelbooruV2PostCodec(),
      );
      final posts = [
        for (var i = 0; i < 120; i++)
          StoredPostSnapshot(
            origin: base.origin,
            common: {
              ...base.common,
              'id': i,
              'createdAt': DateTime.utc(
                2026,
                10,
                14,
              ).add(Duration(minutes: i)).toIso8601String(),
            },
            custom: base.custom,
            codecVersion: base.codecVersion,
          ),
      ];
      final feed = TopicFeed(
        id: 'custom',
        profileId: '00000000-0000-4000-8000-000000000011',
        name: 'Custom',
        maxPosts: 75,
      ).merge(posts);

      expect(feed.posts.length, 75);
      expect(feedPostId(feed.posts.first), 119);
      expect(feedPostId(feed.posts.last), 45);

      final restored = TopicFeed.fromJson(feed.toJson());
      expect(restored.maxPosts, 75);
      expect(restored.posts.length, 75);
      expect(restored.toJson(includeCache: false)['maxPosts'], 75);

      final resized = restored.copyWith(maxPosts: 10);
      expect(resized.posts.length, 10);
      expect(feedPostId(resized.posts.last), 110);
    },
  );

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
    }, profileId: '00000000-0000-4000-8000-000000000011');

    final post = decodeFeedPost(snapshot);
    expect(feedPostId(snapshot), 42);
    expect(post.origin.booruType, BooruType.unknown);
    expect(post.origin.profileIdHint, '00000000-0000-4000-8000-000000000011');
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
    profileIdHint: '00000000-0000-4000-8000-000000000011',
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
