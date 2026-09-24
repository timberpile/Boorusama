// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_codec.dart';
import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_data.dart';
import 'package:boorusama/boorus/e621/posts/post_codec.dart';
import 'package:boorusama/boorus/e621/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

const _postCount = 1000;
const _runCount = 3;
const _catastrophicPhaseLimit = Duration(seconds: 5);
const _serializedSizeLimit = 12 * 1024 * 1024;
const _originCount = 5000;

void main() {
  test(
    'a mixed snapshot workload stays bounded and reports throughput',
    () {
      final posts = [for (var i = 0; i < _postCount; i++) _post(i)];
      _runPipeline(posts.take(20).toList(growable: false));

      final results = [
        for (var run = 0; run < _runCount; run++) _runPipeline(posts),
      ];
      final encode = _median(results.map((result) => result.encodeUs));
      final json = _median(results.map((result) => result.jsonUs));
      final decode = _median(results.map((result) => result.decodeUs));
      final last = results.last;

      expect(last.decodedCount, _postCount);
      expect(last.firstId, 0);
      expect(last.lastId, _postCount - 1);
      expect(last.bytes, lessThan(_serializedSizeLimit));
      expect(
        Duration(microseconds: encode),
        lessThan(_catastrophicPhaseLimit),
      );
      expect(
        Duration(microseconds: json),
        lessThan(_catastrophicPhaseLimit),
      );
      expect(
        Duration(microseconds: decode),
        lessThan(_catastrophicPhaseLimit),
      );

      stdout.writeln(
        'POST_PIPELINE_BENCH posts=$_postCount '
        'encode_ms=${encode / 1000} '
        'json_round_trip_ms=${json / 1000} '
        'decode_ms=${decode / 1000} '
        'snapshot_bytes=${last.bytes}',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('profile resolution stays bounded and reports throughput', () {
    final configs = [
      for (var i = 0; i < 50; i++)
        _config(id: i, url: 'https://profile-$i.example'),
    ];
    final origins = [
      for (var i = 0; i < _originCount; i++)
        PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: BooruType.danbooru.id,
          source: 'https://profile-${i % configs.length}.example/posts/$i',
          profileIdHint: i % configs.length,
        ),
    ];
    const resolver = PostOriginResolver();
    for (final origin in origins.take(20)) {
      resolver.resolve(origin, configs);
    }

    final samples = <int>[];
    var resolvedCount = 0;
    for (var run = 0; run < _runCount; run++) {
      resolvedCount = 0;
      final watch = Stopwatch()..start();
      for (final origin in origins) {
        if (resolver.resolve(origin, configs) is ResolvedPostOrigin) {
          resolvedCount++;
        }
      }
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
    }
    final elapsed = _median(samples);

    expect(resolvedCount, _originCount);
    expect(
      Duration(microseconds: elapsed),
      lessThan(_catastrophicPhaseLimit),
    );
    stdout.writeln(
      'POST_PIPELINE_BENCH origin_resolutions=$_originCount '
      'profiles=${configs.length} resolve_ms=${elapsed / 1000}',
    );
  });
}

({
  int encodeUs,
  int jsonUs,
  int decodeUs,
  int bytes,
  int decodedCount,
  int firstId,
  int lastId,
})
_runPipeline(List<Post> posts) {
  final encodeWatch = Stopwatch()..start();
  final snapshots = [for (final post in posts) _encode(post)];
  encodeWatch.stop();

  final jsonWatch = Stopwatch()..start();
  final json = jsonEncode([
    for (final snapshot in snapshots) snapshot.toJson(),
  ]);
  final restoredSnapshots = [
    for (final value in jsonDecode(json) as List<dynamic>)
      StoredPostSnapshot.fromJson(Map<String, dynamic>.from(value as Map)),
  ];
  jsonWatch.stop();

  final decodeWatch = Stopwatch()..start();
  final decoded = [for (final snapshot in restoredSnapshots) _decode(snapshot)];
  decodeWatch.stop();

  return (
    encodeUs: encodeWatch.elapsedMicroseconds,
    jsonUs: jsonWatch.elapsedMicroseconds,
    decodeUs: decodeWatch.elapsedMicroseconds,
    bytes: utf8.encode(json).length,
    decodedCount: decoded.length,
    firstId: decoded.first.id,
    lastId: decoded.last.id,
  );
}

StoredPostSnapshot _encode(Post post) => switch (post.booruData) {
  DanbooruPostData() => const StoredPostCodec().encode<DanbooruPostData>(
    post,
    dataCodec: const DanbooruPostCodec(),
  ),
  E621PostData() => const StoredPostCodec().encode<E621PostData>(
    post,
    dataCodec: const E621PostCodec(),
  ),
  _ => throw StateError('Unexpected benchmark payload'),
};

Post _decode(StoredPostSnapshot snapshot) {
  final result = switch (BooruType.fromLegacyId(snapshot.origin.booruTypeId)) {
    BooruType.danbooru => const StoredPostCodec().decode<DanbooruPostData>(
      snapshot,
      dataCodec: const DanbooruPostCodec(),
    ),
    BooruType.e621 => const StoredPostCodec().decode<E621PostData>(
      snapshot,
      dataCodec: const E621PostCodec(),
    ),
    _ => throw StateError('Unexpected benchmark origin'),
  };

  return switch (result) {
    StoredPostDecodeSuccess(:final post) => post,
    StoredPostDecodeFailure(:final reason) => throw StateError('$reason'),
  };
}

Post _post(int id) {
  final isDanbooru = id.isEven;
  final type = isDanbooru ? BooruType.danbooru : BooruType.e621;
  final tags = {for (var tag = 0; tag < 30; tag++) 'tag_${id % 11}_$tag'};

  return Post(
    origin: PostOrigin.fromSource(
      booruType: type,
      booruId: type.id,
      source: isDanbooru
          ? 'https://danbooru.donmai.us/posts/$id'
          : 'https://e621.net/posts/$id',
      profileIdHint: isDanbooru ? 12 : 27,
    ),
    core: PostCoreData(
      id: id,
      createdAt: DateTime.utc(2026, 9, 24).add(Duration(seconds: id)),
      thumbnailImageUrl: 'https://cdn.example/$id/180.jpg',
      sampleImageUrl: 'https://cdn.example/$id/720.jpg',
      originalImageUrl: 'https://cdn.example/$id/original.jpg',
      videoUrl: id % 10 == 0 ? 'https://cdn.example/$id/video.webm' : '',
      videoThumbnailUrl: 'https://cdn.example/$id/video.jpg',
      mediaVariants: {
        '180x180': 'https://cdn.example/$id/180.jpg',
        '720x720': 'https://cdn.example/$id/720.jpg',
        'original': 'https://cdn.example/$id/original.jpg',
      },
      thumbnailAspectRatio: 1.2,
      sampleAspectRatio: 1.3,
      originalAspectRatio: 1.4,
      width: 1400,
      height: 1000,
      format: id % 10 == 0 ? 'webm' : 'jpg',
      md5: '0123456789abcdef$id',
      fileSize: 1_000_000 + id,
      duration: id % 10 == 0 ? 12.5 : 0,
      hasSound: id % 10 == 0,
      tags: tags,
      artistTags: {'artist_${id % 7}'},
      characterTags: {'character_${id % 13}'},
      copyrightTags: {'copyright_${id % 5}'},
      rating: Rating.questionable,
      hasComment: id.isEven,
      isTranslated: id % 3 == 0,
      hasParentOrChildren: id % 4 == 0,
      parentId: id % 4 == 0 ? id - 1 : null,
      source: PostSource.from('https://artist.example/works/$id'),
      score: id,
      downvotes: id % 10,
      uploaderId: id % 17,
      uploaderName: 'uploader_${id % 17}',
      status: 'active',
      metadata: const PostMetadata(page: 1, search: 'benchmark', limit: 40),
    ),
    booruData: isDanbooru
        ? DanbooruPostData(
            lastCommentAt: DateTime.utc(2026, 9, 24),
            upScore: id + 10,
            downScore: -(id % 10),
            favCount: id % 100,
            approverId: 4,
            generalTags: tags.take(15).toSet(),
            metaTags: const {'highres', 'translated'},
            hasChildren: id % 4 == 0,
            hasLarge: true,
            pixelHash: 'pixel-$id',
          )
        : E621PostData(
            generalTags: tags.take(10).toSet(),
            metaTags: const {'highres'},
            speciesTags: const {'canine'},
            invalidTags: const {},
            loreTags: const {'example_lore'},
            upScore: id + 10,
            downScore: -(id % 10),
            favCount: id % 100,
            isFavorited: id % 3 == 0,
            sources: [
              E621PostSourceData(
                kind: 'web',
                value: 'https://artist.example/works/$id',
              ),
            ],
            description:
                'Representative benchmark description for post $id. '
                'It contains enough text to exercise snapshot serialization.',
            videoVariants: const [
              E621VideoVariantData(
                type: E621VideoVariantType.v720p,
                url: 'https://cdn.example/video-720.mp4',
                size: 2_000_000,
                width: 1280,
                height: 720,
                codec: 'h264',
                fps: 30,
              ),
            ],
          ),
  );
}

int _median(Iterable<int> values) {
  final sorted = values.toList()..sort();
  return sorted[sorted.length ~/ 2];
}

BooruConfig _config({required int id, required String url}) =>
    BooruConfigData.anonymous(
      booru: BooruType.danbooru,
      booruHint: BooruType.danbooru,
      name: 'Profile $id',
      filter: BooruConfigRatingFilter.none,
      url: url,
      customDownloadFileNameFormat: null,
      customBulkDownloadFileNameFormat: null,
      imageDetaisQuality: null,
      videoQuality: null,
    ).toBooruConfig(id: id)!;
