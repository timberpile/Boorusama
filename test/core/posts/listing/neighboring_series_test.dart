// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/posts/listing/series.dart';

typedef _Post = ({int id, Object? scope, Set<int>? series});
typedef _Case = ({
  String name,
  List<_Post> posts,
  List<int?> series,
  List<List<int>> members,
});

_Post post(int id, Set<int>? series, {Object? scope = 'main'}) => (
  id: id,
  scope: scope,
  series: series,
);

void main() {
  final cases = <_Case>[
    (name: 'Preserves an empty feed', posts: [], series: [], members: []),
    (
      name: 'Leaves a lone series post as a normal post',
      posts: [post(1, {10})],
      series: [null],
      members: [[1]],
    ),
    (
      name: 'Combines two consecutive posts in the same series',
      posts: [post(1, {10}), post(2, {10})],
      series: [10],
      members: [[1, 2]],
    ),
    (
      name: 'Keeps separated runs in their original positions',
      posts: [
        post(1, {10}),
        post(2, {10}),
        post(3, {}),
        post(4, {10}),
        post(5, {10}),
      ],
      series: [10, null, 10],
      members: [[1, 2], [3], [4, 5]],
    ),
    (
      name: 'Treats unavailable membership as a boundary',
      posts: [post(1, {10}), post(2, null), post(3, {10})],
      series: [null, null, null],
      members: [[1], [2], [3]],
    ),
    (
      name: 'Leaves neighbors with no confirmed series separate',
      posts: [post(1, {}), post(2, {})],
      series: [null, null],
      members: [[1], [2]],
    ),
    (
      name: 'Never crosses site or profile scope boundaries',
      posts: [
        post(1, {10}, scope: ('site-a', 'profile-a')),
        post(2, {10}, scope: ('site-a', 'profile-b')),
        post(3, {10}, scope: ('site-b', 'profile-b')),
      ],
      series: [null, null, null],
      members: [[1], [2], [3]],
    ),
    (
      name: 'Does not group posts with an unresolved origin',
      posts: [post(1, {10}, scope: null), post(2, {10}, scope: null)],
      series: [null, null],
      members: [[1], [2]],
    ),
    (
      name: 'Does not merge a chain with no series shared by every post',
      posts: [post(1, {10}), post(2, {10, 20}), post(3, {20})],
      series: [10, null],
      members: [[1, 2], [3]],
    ),
    (
      name: 'Chooses the series shared across the longest leading run',
      posts: [post(1, {10, 20}), post(2, {10, 20}), post(3, {20})],
      series: [20],
      members: [[1, 2, 3]],
    ),
    (
      name: 'Resolves equally long series deterministically',
      posts: [post(1, {20, 10}), post(2, {10, 20})],
      series: [10],
      members: [[1, 2]],
    ),
    (
      name: 'Ignores invalid pool identifiers',
      posts: [post(1, {-1, 0}), post(2, {-1, 0})],
      series: [null, null],
      members: [[1], [2]],
    ),
  ];

  for (final c in cases) {
    test(c.name, () {
      final entries = groupNeighboringSeries(
        c.posts,
        scopeKey: (post) => post.scope,
        seriesIds: (post) => post.series,
      );

      expect(entries.map((entry) => entry.seriesId), c.series);
      expect(
        entries.map((entry) => entry.posts.map((post) => post.id).toList()),
        c.members,
      );
      expect(entries.expand((entry) => entry.posts), c.posts);

      var index = 0;
      for (final entry in entries) {
        expect(entry.firstIndex, index);
        index += entry.posts.length;
      }
    });
  }

  test('Disabling grouping leaves every post independently addressable', () {
    final posts = [post(1, {10}), post(2, {10})];
    final entries = groupNeighboringSeries(
      posts,
      scopeKey: (post) => post.scope,
      seriesIds: (post) => post.series,
      enabled: false,
    );

    expect(entries.map((entry) => entry.seriesId), [null, null]);
    expect(entries.map((entry) => entry.posts.single.id), [1, 2]);
    expect(entries.map((entry) => entry.firstIndex), [0, 1]);
  });

  test('Appending a page extends the final run without changing its cover', () {
    final firstPage = [
      post(100, {}),
      for (var id = 99; id >= 92; id--) post(id, {10}),
    ];
    final nextPage = [
      for (var id = 91; id >= 80; id--) post(id, {10}),
      post(79, {}),
    ];
    final before = groupNeighboringSeries(
      firstPage,
      scopeKey: (post) => post.scope,
      seriesIds: (post) => post.series,
    );
    final after = groupNeighboringSeries(
      [...firstPage, ...nextPage],
      scopeKey: (post) => post.scope,
      seriesIds: (post) => post.series,
    );

    expect(before[1].posts.length, 8);
    expect(after[1].posts.length, 20);
    expect(after[1].posts.first, before[1].posts.first);
    expect(after[1].firstIndex, before[1].firstIndex);
    expect(after[2].posts.single.id, 79);
    expect(after.expand((entry) => entry.posts), [...firstPage, ...nextPage]);
  });
}
