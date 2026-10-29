import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/types/cached_topic_feed_filter.dart';
import 'package:flutter_test/flutter_test.dart';

StoredPostSnapshot snapshot(
  int id, {
  Object? score,
  String? date,
  String host = 'a.example',
  List<String> tags = const ['cat'],
}) => StoredPostSnapshot(
  origin: PostOriginSnapshot(
    booruTypeId: 0,
    booruId: 0,
    sourceHost: host,
    profileIdHint: null,
  ),
  common: {'id': id, 'tags': tags, 'score': score, 'createdAt': date},
  custom: const {},
  codecVersion: 1,
);

void main() {
  final posts = [
    snapshot(1, score: 20, date: '2024-01-01T00:00:00Z'),
    snapshot(2, score: -5, date: '2026-01-01T00:00:00Z'),
    snapshot(3, date: '2025-01-01T00:00:00Z'),
    snapshot(4, score: 20),
  ];
  for (final entry in [
    (sort: CachedTopicFeedSort.stored, ids: [1, 2, 3, 4]),
    (sort: CachedTopicFeedSort.newest, ids: [2, 3, 1, 4]),
    (sort: CachedTopicFeedSort.oldest, ids: [1, 3, 2, 4]),
    (sort: CachedTopicFeedSort.scoreDescending, ids: [1, 4, 3, 2]),
    (sort: CachedTopicFeedSort.scoreAscending, ids: [2, 3, 1, 4]),
  ]) {
    test(
      '${entry.sort.name} sorts cached snapshots without mutating storage',
      () {
        final filter = CachedTopicFeedFilter(sort: entry.sort);
        expect(filter.apply(posts).map((post) => post.common['id']), entry.ids);
        expect(posts.map((post) => post.common['id']), [1, 2, 3, 4]);
        expect(filter.isActive, entry.sort != CachedTopicFeedSort.stored);
      },
    );
  }

  test('sort combines with exact tag and source filters', () {
    final values = [
      ...posts,
      snapshot(5, score: 1000, host: 'other.example'),
      snapshot(6, score: 1000, tags: ['dog']),
    ];
    const filter = CachedTopicFeedFilter(
      query: 'cat',
      sourceHost: 'a.example',
      sort: CachedTopicFeedSort.scoreDescending,
    );
    expect(filter.apply(values).map((post) => post.common['id']), [1, 4, 3, 2]);
  });

  test('malformed legacy score and date metadata have bounded deterministic fallbacks', () {
    final values = [
      snapshot(1, score: double.nan, date: 'not a date'),
      snapshot(2, score: 'unknown'),
      snapshot(3, score: -1, date: '2026-01-01T00:00:00Z'),
    ];
    expect(
      const CachedTopicFeedFilter(sort: CachedTopicFeedSort.scoreDescending)
          .apply(values)
          .map((p) => p.common['id']),
      [1, 2, 3],
    );
    expect(
      const CachedTopicFeedFilter(sort: CachedTopicFeedSort.oldest)
          .apply(values)
          .map((p) => p.common['id']),
      [3, 1, 2],
    );
  });

  test('changing only sort changes the projection identity and clearing restores stored mode', () {
    const unsorted = CachedTopicFeedFilter();
    const sorted = CachedTopicFeedFilter(
      sort: CachedTopicFeedSort.scoreDescending,
    );
    expect(sorted, isNot(unsorted));
    expect(sorted.isActive, isTrue);
    expect(unsorted.isActive, isFalse);
    expect(unsorted.apply(posts), posts);
  });
}
