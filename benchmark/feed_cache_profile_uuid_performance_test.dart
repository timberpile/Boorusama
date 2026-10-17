import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  for (final postCount in [1000, 2000]) {
    test(
      '$postCount snapshots compare full-cache and metadata-only reads',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'following_cache_bench_',
        );
        var box = await Hive.openBox<dynamic>('cache', path: directory.path);
        addTearDown(() async {
          await box.close();
          await directory.delete(recursive: true);
        });
        const profileId = '4d5b640c-cf50-4291-83f6-d6ff359e6389';
        final feeds = [
          for (var feedIndex = 0; feedIndex < 4; feedIndex++)
            _feed(
              feedIndex: feedIndex,
              postCount: postCount,
              profileId: profileId,
            ),
        ];
        final serialized = feeds
            .map((feed) => jsonEncode(feed.toJson()))
            .toList();
        final maps = serialized
            .map((value) => jsonDecode(value) as Map)
            .toList();
        final stopwatch = Stopwatch();
        final fullDecodeSamples = <int>[];
        final metadataDecodeSamples = <int>[];
        final writeSamples = <int>[];
        final coldFullReadSamples = <int>[];
        final coldMetadataReadSamples = <int>[];
        final refreshBurstSamples = <int>[];

        for (var run = 0; run < 6; run++) {
          stopwatch
            ..reset()
            ..start();
          final loaded = maps.map(TopicFeed.fromJson).toList();
          stopwatch.stop();
          expect(
            loaded,
            everyElement(
              predicate<TopicFeed>((feed) => feed.posts.length == postCount),
            ),
          );
          fullDecodeSamples.add(stopwatch.elapsedMicroseconds);

          stopwatch
            ..reset()
            ..start();
          final metadata = maps.map(TopicFeedMetadata.fromJson).toList();
          stopwatch.stop();
          expect(
            metadata,
            everyElement(
              predicate<TopicFeedMetadata>(
                (feed) => feed.sourceIds.length == 10,
              ),
            ),
          );
          metadataDecodeSamples.add(stopwatch.elapsedMicroseconds);

          stopwatch
            ..reset()
            ..start();
          for (final feed in feeds) {
            await box.put(feed.id, feed.toJson());
          }
          await box.flush();
          stopwatch.stop();
          writeSamples.add(stopwatch.elapsedMicroseconds);

          await box.close();
          stopwatch
            ..reset()
            ..start();
          box = await Hive.openBox<dynamic>('cache', path: directory.path);
          final coldFull = box.values
              .whereType<Map>()
              .map(TopicFeed.fromJson)
              .toList();
          stopwatch.stop();
          expect(coldFull, hasLength(feeds.length));
          coldFullReadSamples.add(stopwatch.elapsedMicroseconds);

          stopwatch
            ..reset()
            ..start();
          final coldMetadata = box.values
              .whereType<Map>()
              .map(TopicFeedMetadata.fromJson)
              .toList();
          stopwatch.stop();
          expect(coldMetadata, hasLength(feeds.length));
          coldMetadataReadSamples.add(stopwatch.elapsedMicroseconds);

          final incoming = [
            for (var id = 0; id < 50; id++)
              _snapshot(
                id: 1000000 + run * 100 + id,
                profileId: profileId,
              ),
          ];
          stopwatch
            ..reset()
            ..start();
          final refreshed = [
            for (final feed in coldFull)
              feed.merge(incoming, sourceId: feed.sourceIds.first),
          ];
          stopwatch.stop();
          expect(
            refreshed,
            everyElement(
              predicate<TopicFeed>((feed) => feed.posts.length == postCount),
            ),
          );
          refreshBurstSamples.add(stopwatch.elapsedMicroseconds);
        }

        for (final samples in [
          fullDecodeSamples,
          metadataDecodeSamples,
          writeSamples,
          coldFullReadSamples,
          coldMetadataReadSamples,
          refreshBurstSamples,
        ]) {
          samples.removeAt(0);
          samples.sort();
        }
        final bytes = serialized.fold<int>(
          0,
          (total, value) => total + utf8.encode(value).length,
        );
        stdout.writeln(
          'FEED_CACHE_BENCH feeds=${feeds.length} posts_per_feed=$postCount '
          'tags_per_post=50 bytes=$bytes '
          'full_decode_us=${fullDecodeSamples[2]} '
          'metadata_decode_us=${metadataDecodeSamples[2]} '
          'hive_write_flush_us=${writeSamples[2]} '
          'cold_full_read_us=${coldFullReadSamples[2]} '
          'cold_metadata_read_us=${coldMetadataReadSamples[2]} '
          'refresh_50x4_us=${refreshBurstSamples[2]} '
          'full_range_us=${fullDecodeSamples.first}..${fullDecodeSamples.last} '
          'metadata_range_us=${metadataDecodeSamples.first}..${metadataDecodeSamples.last}',
        );
      },
    );
  }
}

TopicFeed _feed({
  required int feedIndex,
  required int postCount,
  required String profileId,
}) {
  final sourceIds = [
    for (var sourceIndex = 0; sourceIndex < 10; sourceIndex++)
      'folder-${feedIndex ~/ 2}/feed-$feedIndex/source-$sourceIndex',
  ];
  final posts = [
    for (var index = 0; index < postCount; index++)
      _snapshot(
        id: feedIndex * 100000 + index + 1,
        profileId: profileId,
      ),
  ];
  return TopicFeed(
    id: 'benchmark-feed-$feedIndex',
    profileId: profileId,
    name: feedIndex.isEven ? 'Nested $feedIndex' : 'Independent $feedIndex',
    position: feedIndex,
    maxPosts: postCount,
    sourceIds: sourceIds,
    posts: posts,
    initializedSourceIds: sourceIds,
    postSources: {
      for (final (index, post) in posts.indexed)
        feedPostIdentity(post): [sourceIds[index % sourceIds.length]],
    },
  );
}

StoredPostSnapshot _snapshot({required int id, required String profileId}) =>
    feedPostSnapshotFromJson({
      'id': id,
      'createdAt': DateTime.utc(
        2026,
      ).add(Duration(seconds: id)).toIso8601String(),
      'thumbnail': 'https://example.test/thumbnails/$id.jpg',
      'sample': 'https://example.test/samples/$id.jpg',
      'original': 'https://example.test/originals/$id.jpg',
      'tags': [
        for (var tag = 0; tag < 50; tag++)
          switch (tag) {
            0 => 'artist_${id % 37}',
            1 => 'copyright_${id % 23}',
            2 => 'character_${id % 101}',
            _ => 'general_${(id + tag) % 997}',
          },
      ],
      'rating': 'general',
      'width': 1920,
      'height': 1080,
      'format': 'jpg',
      'source': 'https://source.example/posts/$id',
      'score': id % 500,
      'md5': id.toRadixString(16).padLeft(32, '0'),
      'mediaVariants': {
        '180x180': 'https://example.test/180/$id.jpg',
        '720x720': 'https://example.test/720/$id.jpg',
      },
    }, profileId: profileId);
