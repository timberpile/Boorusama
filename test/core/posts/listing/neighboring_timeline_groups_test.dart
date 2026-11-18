import 'dart:math';

import 'package:boorusama/core/posts/listing/src/types/neighboring_timeline_groups.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  List<NeighboringTimelineEntry> project(
    List<Post> posts, {
    Map<int, List<int>> series = const {},
    List<NeighboringTimelineEntry> frozen = const [],
    bool enabled = true,
    bool relatedEnabled = true,
    Object? Function(Post)? scope,
  }) => groupNeighboringTimeline(
    posts,
    scopeKey: scope ?? (p) => p.origin,
    seriesIds: (p) => series[p.id],
    frozen: frozen,
    enabled: enabled,
    relatedEnabled: relatedEnabled,
  );
  List<List<int>> ids(List<NeighboringTimelineEntry> entries) => [
    for (final entry in entries) entry.posts.map((p) => p.id).toList(),
  ];

  test(
    'direct family and siblings group without swallowing intervening results',
    () {
      final result = project([
        testRelatedPost(10, hasChildren: true),
        testRelatedPost(99),
        testRelatedPost(11, parent: 10),
        testRelatedPost(12, parent: 10),
      ]);
      expect(ids(result), [
        [10, 11, 12],
        [99],
      ]);
      expect(result.first.indices, [0, 2, 3]);
      expect(result.first.family!.anchorId, 10);
      expect(result.first.seriesId, isNull);
      final siblings = project([
        testRelatedPost(11, parent: 10),
        testRelatedPost(12, parent: 10),
      ]);
      expect(siblings.single.family, result.first.family);
    },
  );

  test(
    'disabling Related expands its members while preserving frozen Series',
    () {
      final posts = [
        testRelatedPost(11, parent: 10),
        testRelatedPost(21),
        testRelatedPost(22),
        testRelatedPost(12, parent: 10),
      ];
      const memberships = {
        21: [9],
        22: [9],
      };
      final grouped = project(posts, series: memberships);
      final disabled = project(
        posts,
        series: {
          ...memberships,
          11: [9], // Late metadata must not replace the existing Series cover.
        },
        frozen: grouped,
        relatedEnabled: false,
      );
      expect(ids(disabled), [
        [11],
        [21, 22],
        [12],
      ]);
      expect(disabled.where((entry) => entry.family != null), isEmpty);
      expect(disabled[1].firstIndex, grouped[1].firstIndex);
      expect(disabled[1].seriesId, 9);
      expect(disabled.expand((entry) => entry.indices).toList()..sort(), [
        0,
        1,
        2,
        3,
      ]);
    },
  );

  test('Related absorbs distant members without a lookahead limit', () {
    final result = project([
      testRelatedPost(1, parent: 10),
      for (var i = 0; i < 20; i++) testRelatedPost(100 + i),
      testRelatedPost(2, parent: 10),
    ]);
    expect(result.first.indices, [0, 21]);
    expect(ids(result).first, [1, 2]);
    expect(result.length, 21);
  });

  test(
    'verified singleton child and parent group, unrelated Posts stay raw',
    () {
      final child = project([testRelatedPost(11, parent: 10)]).single;
      expect(child.family!.anchorId, 10);
      expect(child.indices, [0]);
      final parent = project([testRelatedPost(10, hasChildren: true)]).single;
      expect(parent.family, child.family);
      expect(project([testRelatedPost(99)]).single.family, isNull);
    },
  );

  test('Series claims overlap before Related and never nests', () {
    final result = project(
      [
        testRelatedPost(10, hasChildren: true),
        testRelatedPost(11, parent: 10),
        testRelatedPost(50),
        testRelatedPost(12, parent: 10),
      ],
      series: {
        11: [9],
        50: [9],
      },
    );
    expect(ids(result), [
      [10, 12],
      [11, 50],
    ]);
    expect(result.first.family!.anchorId, 10);
    expect(result.last.seriesId, 9);
    expect(result.last.family, isNull);
  });

  test('Series priority leaves a later overlapping family accessible', () {
    final posts = [
      testRelatedPost(11, parent: 10),
      testRelatedPost(50),
      for (var i = 0; i < 12; i++) testRelatedPost(100 + i),
      testRelatedPost(12, parent: 10),
    ];
    final entries = project(
      posts,
      series: {
        11: [9],
        50: [9],
      },
    );
    expect(entries.first.seriesId, 9);
    expect(entries.first.indices, [0, 1]);
    expect(entries.last.family!.anchorId, 10);
    expect(entries.last.indices, [14]);
    expect(
      entries.expand((entry) => entry.indices).toList()..sort(),
      List.generate(posts.length, (index) => index),
    );
    final appended = project(
      [...posts, testRelatedPost(13, parent: 10)],
      frozen: entries,
      series: {
        11: [9],
        50: [9],
      },
    );
    expect(appended.first.indices, [0, 1]);
    expect(appended.last.indices, [14, 15]);
  });

  test('direct canonical families do not flatten grandchildren', () {
    final result = project([
      testRelatedPost(10, hasChildren: true),
      testRelatedPost(11, parent: 10, hasChildren: true),
      testRelatedPost(12, parent: 11),
    ]);
    expect(ids(result), [
      [10, 11],
      [12],
    ]);
    expect(result.map((entry) => entry.family!.anchorId), [10, 11]);
  });

  test(
    'source/account mismatch and disabled projection do not aggregate families',
    () {
      final posts = [
        testRelatedPost(11, parent: 10),
        testRelatedPost(12, parent: 10),
      ];
      expect(project(posts, enabled: false).length, 2);
      expect(
        project([
          posts.first,
          testRelatedPost(12, parent: 10, host: 'other.example'),
        ]).length,
        2,
      );
      expect(
        project(
          posts,
          scope: (p) => p.id == 11 ? 'account-a' : 'account-b',
        ).length,
        2,
      );
      expect(project(posts, scope: (_) => null).length, 2);
      expect(project([posts.first]).single.family!.anchorId, 10);
    },
  );

  test('pagination extends built Related but never steals built ordinary or Series tiles', () {
    final posts = [
      testRelatedPost(10, hasChildren: true),
      testRelatedPost(11, parent: 10),
      testRelatedPost(50),
    ];
    final initial = project(posts);
    final next = project(
      [...posts, testRelatedPost(12, parent: 10), testRelatedPost(51)],
      frozen: initial,
      series: {
        50: [9],
        51: [9],
        11: [9],
      },
    );
    expect(ids(next), [
      [10, 11, 12],
      [50],
      [51],
    ]);
    expect(next.first.firstIndex, initial.first.firstIndex);
    expect(next.first.family, initial.first.family);
    final ordinary = project([testRelatedPost(10)]);
    expect(
      ids(
        project([
          testRelatedPost(10, hasChildren: true),
          testRelatedPost(11, parent: 10),
        ], frozen: ordinary),
      ),
      [
        [10],
        [11],
      ],
    );
    final series = project(
      posts,
      series: {
        10: [9],
        11: [9],
      },
    );
    expect(
      ids(
        project(
          [...posts, testRelatedPost(12, parent: 10)],
          frozen: series,
          series: {
            10: [9],
            11: [9],
            12: [9],
          },
        ),
      ),
      [
        [10, 11, 12],
        [50],
      ],
    );
  });

  test('first child keeps its cover and occurrence across distant appends', () {
    final first = [testRelatedPost(11, parent: 10)];
    final frozen = project(first);
    final result = project([
      ...first,
      for (var i = 0; i < 30; i++) testRelatedPost(100 + i),
      testRelatedPost(10, hasChildren: true),
      testRelatedPost(12, parent: 10),
    ], frozen: frozen);
    expect(ids(result).first, [11, 10, 12]);
    expect(result.first.indices, [0, 31, 32]);
    expect(result.first.firstIndex, frozen.single.firstIndex);
    expect(result.first.family, frozen.single.family);
    expect(result.first.posts.first, frozen.single.posts.first);
  });

  test('late Series metadata never steals a frozen singleton Related card', () {
    final child = testRelatedPost(11, parent: 10);
    final frozen = project([child]);
    final result = project(
      [child, testRelatedPost(50)],
      series: {
        11: [42],
        50: [42],
      },
      frozen: frozen,
    );
    expect(ids(result), [
      [11],
      [50],
    ]);
    expect(result.first.family, frozen.single.family);
    expect(result.every((entry) => entry.seriesId == null), isTrue);
  });

  test('frozen interleaved entries never double-claim an appended member', () {
    final first = [
      testRelatedPost(11, parent: 10),
      testRelatedPost(99),
      testRelatedPost(12, parent: 10),
      testRelatedPost(21, parent: 20),
    ];
    final frozen = project(first);
    final result = project([
      ...first,
      testRelatedPost(13, parent: 10),
      testRelatedPost(22, parent: 20),
    ], frozen: frozen);
    expect(ids(result), [
      [11, 12, 13],
      [99],
      [21, 22],
    ]);
    expect(
      [for (final entry in result) ...entry.indices]..sort(),
      List.generate(6, (i) => i),
    );
  });

  test(
    'random mixed projections retain every raw index exactly once across pages',
    () {
      final random = Random(134);
      for (var run = 0; run < 40; run++) {
        final posts = [
          for (var i = 0; i < 40; i++)
            testRelatedPost(
              100 + i,
              parent: random.nextBool() ? 1 + random.nextInt(5) : null,
            ),
        ];
        final series = {
          for (final p in posts)
            if (random.nextBool()) p.id: [1 + random.nextInt(4)],
        };
        final prefix = project(posts.take(20).toList(), series: series);
        final result = project(posts, series: series, frozen: prefix);
        final indices = [for (final e in result) ...e.indices]..sort();
        expect(indices, List.generate(posts.length, (i) => i));
        for (final e in result) {
          if (e.family != null) {
            expect(e.posts, isNotEmpty);
            expect(e.posts.every(e.family!.contains), isTrue);
          }
        }
      }
    },
  );
}
