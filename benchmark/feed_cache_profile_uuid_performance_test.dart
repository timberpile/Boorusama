import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  for (final postCount in [1000, 2000]) {
    test(
      '$postCount snapshots report aggregate Hive writes and cold reads',
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
        final feed = TopicFeed(
          id: 'benchmark-feed',
          profileId: profileId,
          name: 'Benchmark',
          maxPosts: postCount,
          sourceIds: const ['source-a', 'source-b'],
          posts: [
            for (var id = 1; id <= postCount; id++)
              feedPostSnapshotFromJson({
                'id': id,
                'createdAt': DateTime.utc(2026).toIso8601String(),
                'thumbnail': 'https://example.test/thumbnails/$id.jpg',
                'sample': 'https://example.test/samples/$id.jpg',
                'original': 'https://example.test/originals/$id.jpg',
                'tags': ['cat', 'outdoors', 'sunset', 'artist_$id'],
                'rating': 'general',
                'width': 1920,
                'height': 1080,
                'format': 'jpg',
                'mediaVariants': {
                  '180x180': 'https://example.test/180/$id.jpg',
                },
              }, profileId: profileId),
          ],
        );
        final serialized = jsonEncode(feed.toJson());
        final stopwatch = Stopwatch();
        final samples = <int>[];
        final writeSamples = <int>[];
        final readSamples = <int>[];
        for (var run = 0; run < 6; run++) {
          stopwatch
            ..reset()
            ..start();
          final loaded = TopicFeed.fromJson(
            jsonDecode(serialized) as Map,
          );
          stopwatch.stop();
          expect(loaded.posts, hasLength(postCount));
          samples.add(stopwatch.elapsedMicroseconds);
          // The first pass warms code and filesystem caches; record five repeats.
          stopwatch
            ..reset()
            ..start();
          await box.put('feed', feed.toJson());
          await box.flush();
          stopwatch.stop();
          writeSamples.add(stopwatch.elapsedMicroseconds);
          await box.close();
          stopwatch
            ..reset()
            ..start();
          final reopened = await Hive.openBox<dynamic>(
            'cache',
            path: directory.path,
          );
          box = reopened;
          final cold = TopicFeed.fromJson(
            reopened.get('feed') as Map,
          );
          stopwatch.stop();
          expect(cold.posts, hasLength(postCount));
          readSamples.add(stopwatch.elapsedMicroseconds);
        }
        samples.removeAt(0);
        writeSamples.removeAt(0);
        readSamples.removeAt(0);
        samples.sort();
        writeSamples.sort();
        readSamples.sort();
        stdout.writeln(
          'FEED_CACHE_BENCH posts=$postCount '
          'bytes=${utf8.encode(serialized).length} load_us=${samples[2]} '
          'hive_write_flush_us=${writeSamples[2]} write_range_us=${writeSamples.first}..${writeSamples.last} '
          'cold_read_decode_us=${readSamples[2]} read_range_us=${readSamples.first}..${readSamples.last}',
        );
      },
    );
  }
}
