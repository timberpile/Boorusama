import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  final timestamp = DateTime.utc(2026, 9, 14, 10);
  final items = [
    topicFixture(id: 'undated-a', checked: false),
    topicFixture(
      id: 'dated-a',
      previewCount: 1,
      postCreatedAt: timestamp,
    ),
    topicFixture(
      id: 'dated-b',
      previewCount: 1,
      postCreatedAt: timestamp,
    ),
    topicFixture(id: 'undated-b'),
  ];

  test(
    'alphabetical order uses displayed names and query fallback with stable ties',
    () {
      final topics = [
        topicFixture(id: 'z', name: 'Zebra'),
        topicFixture(id: 'a-first', name: 'apple'),
        topicFixture(id: 'query', name: null, query: 'banana'),
        topicFixture(id: 'a-second', name: 'APPLE'),
      ];
      expect(
        sortFollowingTopics(
          topics,
          FollowingTopicSort.nameAsc,
        ).map((t) => t.id),
        ['a-first', 'a-second', 'query', 'z'],
      );
      expect(topics.map((t) => t.id), ['z', 'a-first', 'query', 'a-second']);
    },
  );

  test(
    'oldest post view keeps manual order within equal and undated groups',
    () {
      expect(
        sortFollowingTopics(items, FollowingTopicSort.lastPostOldest).map(
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
        topicFixture(
          id: 'read-newest',
          unreadCount: 0,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 14),
        ),
        topicFixture(
          id: 'new-older',
          unreadCount: 1,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 11),
        ),
        topicFixture(
          id: 'new-newer',
          unreadCount: 20,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 12),
        ),
        topicFixture(
          id: 'read-older',
          unreadCount: 0,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 10),
        ),
      ];

      expect(
        sortFollowingTopics(
          mixed,
          FollowingTopicSort.updatesFirst,
        ).map((item) => item.id),
        ['new-newer', 'new-older', 'read-newest', 'read-older'],
      );
    },
  );

  test('dated entries precede undated entries within NEW and read groups', () {
    final mixed = [
      topicFixture(id: 'new-undated', unreadCount: 1),
      topicFixture(
        id: 'read-dated',
        unreadCount: 0,
        previewCount: 1,
        postCreatedAt: timestamp,
      ),
      topicFixture(
        id: 'new-dated',
        unreadCount: 1,
        previewCount: 1,
        postCreatedAt: timestamp,
      ),
      topicFixture(id: 'read-undated', unreadCount: 0),
    ];

    expect(
      sortFollowingTopics(
        mixed,
        FollowingTopicSort.updatesFirst,
      ).map((item) => item.id),
      ['new-dated', 'new-undated', 'read-dated', 'read-undated'],
    );
  });

  test('equal and missing dates retain manual order within both groups', () {
    final mixed = [
      topicFixture(id: 'read-undated-a', unreadCount: 0),
      topicFixture(id: 'new-dated-a', unreadCount: 1, previewCount: 1),
      topicFixture(id: 'new-undated-a', unreadCount: 1),
      topicFixture(id: 'read-dated-a', unreadCount: 0, previewCount: 1),
      topicFixture(id: 'new-dated-b', unreadCount: 1, previewCount: 1),
      topicFixture(id: 'read-undated-b', unreadCount: 0),
      topicFixture(id: 'new-undated-b', unreadCount: 1),
      topicFixture(id: 'read-dated-b', unreadCount: 0, previewCount: 1),
    ];

    expect(
      sortFollowingTopics(mixed, FollowingTopicSort.updatesFirst).map(
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
    expect(sortFollowingTopics([], FollowingTopicSort.updatesFirst), isEmpty);
  });
}
