import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a full feed cache reports serialized size and load time', () {
    const profileId = '4d5b640c-cf50-4291-83f6-d6ff359e6389';
    final feed = SearchFollowingFeed(
      id: 'benchmark-feed',
      profileId: profileId,
      name: 'Benchmark',
      sourceIds: const ['source-a', 'source-b'],
      posts: [
        for (var id = 1; id <= followingFeedRetention; id++)
          feedPostSnapshotFromJson({
            'id': id,
            'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            'thumbnail': 'https://example.test/thumbnails/$id.jpg',
            'sample': 'https://example.test/samples/$id.jpg',
            'original': 'https://example.test/originals/$id.jpg',
            'tags': ['cat', 'outdoors', 'sunset', 'artist_$id'],
            'rating': 'general',
            'width': 1920,
            'height': 1080,
            'format': 'jpg',
            'mediaVariants': {'180x180': 'https://example.test/180/$id.jpg'},
          }, profileId: profileId),
      ],
    );
    final serialized = jsonEncode(feed.toJson());
    final stopwatch = Stopwatch();
    final samples = <int>[];
    for (var run = 0; run < 5; run++) {
      stopwatch
        ..reset()
        ..start();
      final loaded = SearchFollowingFeed.fromJson(
        jsonDecode(serialized) as Map,
      );
      stopwatch.stop();
      expect(loaded.posts, hasLength(followingFeedRetention));
      samples.add(stopwatch.elapsedMicroseconds);
    }
    samples.sort();
    stdout.writeln(
      'FEED_CACHE_BENCH posts=$followingFeedRetention '
      'bytes=${utf8.encode(serialized).length} load_us=${samples[2]}',
    );
  });
}
