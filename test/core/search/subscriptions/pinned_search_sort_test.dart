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

  for (final sort in [
    PinnedSearchSort.lastPostNewest,
    PinnedSearchSort.lastPostOldest,
  ]) {
    test('${sort.name} keeps manual order within equal and undated groups', () {
      expect(sortPinnedSearches(items, sort).map((item) => item.id), [
        'dated-a',
        'dated-b',
        'undated-a',
        'undated-b',
      ]);
    });
  }
}
