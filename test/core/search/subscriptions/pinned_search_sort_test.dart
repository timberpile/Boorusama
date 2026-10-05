import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  final timestamp = DateTime.utc(2026, 9, 14, 10);
  final items = [
    pinnedFixture(id: 'undated-a', checked: false),
    pinnedFixture(
      id: 'dated-a',
      previewCount: 1,
      postCreatedAt: timestamp,
    ),
    pinnedFixture(
      id: 'dated-b',
      previewCount: 1,
      postCreatedAt: timestamp,
    ),
    pinnedFixture(id: 'undated-b'),
  ];

  test(
    'oldest post view keeps manual order within equal and undated groups',
    () {
      expect(
        sortPinnedSearches(items, PinnedSearchSort.lastPostOldest).map(
          (item) => item.id,
        ),
        [
          'dated-a',
          'dated-b',
          'undated-a',
          'undated-b',
        ],
      );
    },
  );

  test(
    'NEW searches precede newer read searches while each group follows recency',
    () {
      final mixed = [
        pinnedFixture(
          id: 'read-newest',
          unreadCount: 0,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 14),
        ),
        pinnedFixture(
          id: 'new-older',
          unreadCount: 1,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 11),
        ),
        pinnedFixture(
          id: 'new-newer',
          unreadCount: 20,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 12),
        ),
        pinnedFixture(
          id: 'read-older',
          unreadCount: 0,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 10),
        ),
      ];

      expect(
        sortPinnedSearches(
          mixed,
          PinnedSearchSort.updatesFirst,
        ).map((item) => item.id),
        ['new-newer', 'new-older', 'read-newest', 'read-older'],
      );
    },
  );

  test('dated entries precede undated entries within NEW and read groups', () {
    final mixed = [
      pinnedFixture(id: 'new-undated', unreadCount: 1),
      pinnedFixture(
        id: 'read-dated',
        unreadCount: 0,
        previewCount: 1,
        postCreatedAt: timestamp,
      ),
      pinnedFixture(
        id: 'new-dated',
        unreadCount: 1,
        previewCount: 1,
        postCreatedAt: timestamp,
      ),
      pinnedFixture(id: 'read-undated', unreadCount: 0),
    ];

    expect(
      sortPinnedSearches(
        mixed,
        PinnedSearchSort.updatesFirst,
      ).map((item) => item.id),
      ['new-dated', 'new-undated', 'read-dated', 'read-undated'],
    );
  });

  test('equal and missing dates retain manual order within both groups', () {
    final mixed = [
      pinnedFixture(id: 'read-undated-a', unreadCount: 0),
      pinnedFixture(id: 'new-dated-a', unreadCount: 1, previewCount: 1),
      pinnedFixture(id: 'new-undated-a', unreadCount: 1),
      pinnedFixture(id: 'read-dated-a', unreadCount: 0, previewCount: 1),
      pinnedFixture(id: 'new-dated-b', unreadCount: 1, previewCount: 1),
      pinnedFixture(id: 'read-undated-b', unreadCount: 0),
      pinnedFixture(id: 'new-undated-b', unreadCount: 1),
      pinnedFixture(id: 'read-dated-b', unreadCount: 0, previewCount: 1),
    ];

    expect(
      sortPinnedSearches(mixed, PinnedSearchSort.updatesFirst).map(
        (item) => item.id,
      ),
      [
        'new-dated-a',
        'new-dated-b',
        'new-undated-a',
        'new-undated-b',
        'read-dated-a',
        'read-dated-b',
        'read-undated-a',
        'read-undated-b',
      ],
    );
  });

  test('empty updates view stays empty', () {
    expect(sortPinnedSearches([], PinnedSearchSort.updatesFirst), isEmpty);
  });
}
