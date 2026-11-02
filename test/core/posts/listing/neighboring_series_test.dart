import 'dart:math';

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
      posts: [
        post(1, {10}),
      ],
      series: [null],
      members: [
        [1],
      ],
    ),
    (
      name: 'Combines two consecutive posts in the same series',
      posts: [
        post(1, {10}),
        post(2, {10}),
      ],
      series: [10],
      members: [
        [1, 2],
      ],
    ),
    (
      name: 'Combines separated members while preserving intervening posts',
      posts: [
        post(1, {10}),
        post(2, {10}),
        post(3, {}),
        post(4, {10}),
        post(5, {10}),
      ],
      series: [10, null],
      members: [
        [1, 2, 4, 5],
        [3],
      ],
    ),
    (
      name: 'Leaves unavailable membership visible between confirmed members',
      posts: [
        post(1, {10}),
        post(2, null),
        post(3, {10}),
      ],
      series: [10, null],
      members: [
        [1, 3],
        [2],
      ],
    ),
    (
      name: 'Leaves neighbors with no confirmed series separate',
      posts: [post(1, {}), post(2, {})],
      series: [null, null],
      members: [
        [1],
        [2],
      ],
    ),
    (
      name: 'Never crosses site or profile scope boundaries',
      posts: [
        post(1, {10}, scope: ('site-a', 'profile-a')),
        post(2, {10}, scope: ('site-a', 'profile-b')),
        post(3, {10}, scope: ('site-b', 'profile-b')),
      ],
      series: [null, null, null],
      members: [
        [1],
        [2],
        [3],
      ],
    ),
    (
      name: 'Does not group posts with an unresolved origin',
      posts: [
        post(1, {10}, scope: null),
        post(2, {10}, scope: null),
      ],
      series: [null, null],
      members: [
        [1],
        [2],
      ],
    ),
    (
      name: 'Does not merge a chain with no series shared by every post',
      posts: [
        post(1, {10}),
        post(2, {10, 20}),
        post(3, {20}),
      ],
      series: [10, null],
      members: [
        [1, 2],
        [3],
      ],
    ),
    (
      name: 'Chooses the series shared across the longest leading run',
      posts: [
        post(1, {10, 20}),
        post(2, {10, 20}),
        post(3, {20}),
      ],
      series: [20],
      members: [
        [1, 2, 3],
      ],
    ),
    (
      name: 'Resolves equally long series deterministically',
      posts: [
        post(1, {20, 10}),
        post(2, {10, 20}),
      ],
      series: [10],
      members: [
        [1, 2],
      ],
    ),
    (
      name: 'Ignores invalid pool identifiers',
      posts: [
        post(1, {-1, 0}),
        post(2, {-1, 0}),
      ],
      series: [null, null],
      members: [
        [1],
        [2],
      ],
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
      final indexed = [for (final e in entries) ...e.indices]..sort();
      expect(indexed, List.generate(c.posts.length, (i) => i));
      expect(
        entries.map((e) => e.firstIndex),
        orderedEquals(
          entries.map((e) => e.firstIndex).toList()..sort(),
        ),
      );
      for (final entry in entries) {
        expect(entry.posts, [for (final i in entry.indices) c.posts[i]]);
      }
    });
  }

  List<NeighboringSeriesEntry<_Post>> project(
    List<_Post> posts, {
    List<NeighboringSeriesEntry<_Post>> frozen = const [],
  }) => groupNeighboringSeries(
    posts,
    scopeKey: (p) => p.scope,
    seriesIds: (p) => p.series,
    frozen: frozen,
  );

  test('fifth raw result matches and every match extends the window', () {
    final posts = [
      for (var i = 0; i < 17; i++) post(i, i % 5 == 0 ? {10} : {}),
    ];
    final entries = project(posts);
    expect(entries.first.indices, [0, 5, 10, 15]);
    expect(entries.first.posts.map((p) => p.id), [0, 5, 10, 15]);
    expect(entries.skip(1).map((e) => e.firstIndex), [
      1,
      2,
      3,
      4,
      6,
      7,
      8,
      9,
      11,
      12,
      13,
      14,
      16,
    ]);
    expect(
      (entries.expand((e) => e.indices).toList()..sort()),
      List.generate(17, (i) => i),
    );
  });

  test('sixth raw result starts a distinct group', () {
    final posts = [
      for (var i = 0; i < 8; i++)
        post(i, {
          if ([0, 1, 7].contains(i)) 10,
        }),
    ];
    final entries = project(posts);
    expect(entries.first.indices, [0, 1]);
    expect(entries.last.seriesId, isNull);
    expect(entries.last.firstIndex, 7);
  });

  test('overlapping Series cannot steal or duplicate another group member', () {
    final entries = project([
      post(0, {10, 20}),
      post(1, {20}),
      post(2, {10, 20}),
      post(3, {10}),
      post(4, {30}),
      post(5, {30}),
    ]);
    expect(entries.map((e) => e.seriesId), [10, null, 30]);
    expect(entries.map((e) => e.indices), [
      [0, 2, 3],
      [1],
      [4, 5],
    ]);
  });

  test(
    'a frozen noncontiguous group extends across a page and retains holes',
    () {
      final first = [
        post(0, {10}),
        post(1, {}),
        post(2, {10}),
        post(3, {}),
      ];
      final before = project(first);
      final after = project([
        ...first,
        post(4, {}),
        post(5, {10}),
        post(6, {}),
      ], frozen: before);
      expect(after.first.indices, [0, 2, 5]);
      expect(after.first.posts.first, before.first.posts.first);
      expect(after.skip(1).map((e) => e.firstIndex), [1, 3, 4, 6]);
      expect(
        after.expand((e) => e.indices).toList()..sort(),
        List.generate(7, (i) => i),
      );
    },
  );

  test('delayed metadata never consumes frozen single posts or changes Series identity', () {
    final before = project([
      post(0, {10}),
      post(1, {10}),
      post(2, {}),
      post(3, {}),
    ]);
    final after = project([
      post(0, {10, 20}),
      post(1, {10, 20}),
      post(2, {10, 20}),
      post(3, {10, 20}),
      post(4, {10}),
    ], frozen: before);
    expect(after.first.seriesId, 10);
    expect(after.map((e) => e.indices), [
      [0, 1, 4],
      [2],
      [3],
    ]);
  });

  test('frozen raw singles leave later unseen groups free to form', () {
    final initial = project([post(0, {}), post(1, {}), post(2, {})]);
    final after = project([
      post(0, {10}),
      post(1, {10}),
      post(2, {}),
      post(3, {20}),
      post(4, {}),
      post(5, {20}),
    ], frozen: initial.take(2).toList());
    expect(after.map((e) => e.indices), [
      [0],
      [1],
      [2],
      [3, 5],
      [4],
    ]);
  });

  test('seeded overlapping windows preserve every raw index through append and metadata changes', () {
    final random = Random(68);
    for (var sample = 0; sample < 100; sample++) {
      _Post item(int i) => post(i, {
        for (var id = 1; id <= 4; id++)
          if (random.nextBool()) id,
      }, scope: random.nextInt(8) == 0 ? 'other' : 'main');
      final original = [for (var i = 0; i < 70; i++) item(i)];
      final before = project(original);
      final frozen = before.take(random.nextInt(before.length + 1)).toList();
      final changed = [
        for (var i = 0; i < 90; i++)
          i < 70
              ? (
                  id: original[i].id,
                  scope: original[i].scope,
                  series: item(i).series,
                )
              : item(i),
      ];
      final after = project(changed, frozen: frozen);
      expect(
        after.expand((e) => e.indices).toList()..sort(),
        List.generate(90, (i) => i),
      );
      expect(
        after.map((e) => e.firstIndex).toList(),
        after.map((e) => e.firstIndex).toList()..sort(),
      );
      for (final fixed in frozen) {
        final kept = after.singleWhere((e) => e.firstIndex == fixed.firstIndex);
        expect(kept.seriesId, fixed.seriesId);
        expect(kept.indices, containsAll(fixed.indices));
        if (fixed.seriesId == null) expect(kept.indices, fixed.indices);
      }
      for (final entry in after) {
        expect(entry.posts, [for (final i in entry.indices) changed[i]]);
        for (var i = 1; i < entry.indices.length; i++) {
          expect(entry.indices[i] - entry.indices[i - 1], lessThanOrEqualTo(5));
        }
      }
    }
  });

  test('Disabling grouping leaves every post independently addressable', () {
    final posts = [
      post(1, {10}),
      post(2, {10}),
    ];
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
