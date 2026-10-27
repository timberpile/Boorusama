import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/types/cached_topic_feed_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final snapshots = [
    _snapshot(3, 'a.example', ['Cat', 'blue_hair', 'blue_hair']),
    _snapshot(2, 'b.example', ['cat', 'dog']),
    _snapshot(1, 'a.example', ['dog']),
    _snapshot(0, '', null),
  ];

  test('combines exact positive and negative tags without changing order', () {
    final filtered = const CachedTopicFeedFilter(query: 'CAT -dog')
        .apply(snapshots);
    expect(filtered, [snapshots.first]);
    expect(const CachedTopicFeedFilter(query: 'ca').apply(snapshots), isEmpty);
    expect(const CachedTopicFeedFilter(query: '-cat').apply(snapshots), [
      snapshots[2],
      snapshots[3],
    ]);
    expect(snapshots.map((post) => post.common['id']), [3, 2, 1, 0]);
  });

  test(
    'isolates source hosts and does not infer an origin for missing data',
    () {
      final filtered = const CachedTopicFeedFilter(
        query: 'cat',
        sourceHost: 'https://A.example/',
      ).apply(snapshots);
      expect(filtered, [snapshots.first]);
      expect(
        const CachedTopicFeedFilter(sourceHost: 'unknown.example')
            .apply(snapshots),
        isEmpty,
      );
      expect(const CachedTopicFeedFilter().apply(snapshots), snapshots);
    },
  );

  test('builds suggestions only from saved tags with per-post counts', () {
    final index = cachedTopicFeedTagIndex(snapshots);
    expect(index.byName['cat']!.count, 2);
    expect(index.byName['blue_hair']!.count, 1);
    final scoped = cachedTopicFeedTagIndex(snapshots, sourceHost: 'b.example');
    expect(scoped.byName.keys.toSet(), {'cat', 'dog'});
    expect(cachedTopicFeedSourceHosts(snapshots), ['a.example', 'b.example']);
  });

  test('retains per-source snapshot categories and cache URLs', () {
    final snapshots = [
      for (final (host, category) in [
        ('a.example', 'artist'),
        ('b.example', 'character'),
      ])
        StoredPostSnapshot(
          origin: _snapshot(1, host, []).origin,
          common: {
            'tags': const ['Same Tag', 'plain'],
            '${category}Tags': const ['same_tag'],
          },
          custom: const {},
          codecVersion: 1,
        ),
    ];
    final index = cachedTopicFeedTagIndex(
      snapshots,
      siteUrl: (s) => 'https://${s.origin.sourceHost}/nested/',
    );
    final sources = index.byName['same_tag']!.sources;
    expect(
      sources.map((source, categories) => MapEntry(source.url, categories)),
      {
        'https://a.example/nested/': {'artist'},
        'https://b.example/nested/': {'character'},
      },
    );
    expect(index.byName['plain']!.sources.values, everyElement(isEmpty));
    final scoped = cachedTopicFeedTagIndex(snapshots, sourceHost: 'a.example');
    expect(scoped.byName['same_tag']!.sources.values.single, {'artist'});
  });

  test('ignores malformed and blank tags without treating them as matches', () {
    final malformed = [
      _snapshot(4, 'a.example', [1, null, '', ' Cat ']),
    ];
    expect(cachedTopicFeedTagIndex(malformed).byName.keys, ['cat']);
    expect(
      const CachedTopicFeedFilter(query: 'cat').apply(malformed),
      malformed,
    );
    expect(
      const CachedTopicFeedFilter(query: 'null').apply(malformed),
      isEmpty,
    );
  });
}

StoredPostSnapshot _snapshot(int id, String host, Object? tags) =>
    StoredPostSnapshot(
      origin: PostOriginSnapshot(
        booruTypeId: 0,
        booruId: 0,
        sourceHost: host,
        profileIdHint: null,
      ),
      common: {'id': id, 'tags': tags},
      custom: const {},
      codecVersion: 1,
    );
