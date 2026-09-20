import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'subscription_test_utils.dart';

void main() {
  final uploadedAt = DateTime.utc(2026, 9, 14);

  for (final c in [
    (total: 2, hasMore: false, maxPage: null),
    (total: 50000, hasMore: true, maxPage: null),
    (total: 50000, hasMore: true, maxPage: 1),
  ]) {
    test(
      'loads one bounded snapshot for ${c.total} results with continuation ${c.hasMore} and cap ${c.maxPage}',
      () async {
        final requests = <(int, int)>[];
        final posts = [
          TestSearchPost(2, uploadedAt),
          TestSearchPost(1, uploadedAt),
        ];
        final result = await ChronologicalSearchScanner().scanSnapshot(
          fetchPage: (page, limit) async {
            requests.add((page, limit));
            return Either.right(
              PostResult(
                posts: posts,
                total: c.total,
                hasMore: c.hasMore,
                maxPage: c.maxPage,
              ),
            );
          },
        );
        expect(requests, [(1, 50)]);
        expect(result, LoadedSearchSnapshot(posts));
      },
    );
  }

  test(
    'limits processing when a server returns more than the requested budget',
    () async {
      final posts = [
        for (var id = 100; id > 0; id--) TestSearchPost(id, uploadedAt),
        TestSearchPost(0, null),
      ];
      final result = await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.right(posts.toResult()),
      );
      expect((result as LoadedSearchSnapshot).posts.map((post) => post.id), [
        for (var id = 100; id > 50; id--) id,
      ]);
    },
  );

  test('keeps distinct posts with equal timestamps in a snapshot', () async {
    final posts = [
      TestSearchPost(2, uploadedAt),
      TestSearchPost(1, uploadedAt),
    ];
    final result = await ChronologicalSearchScanner().scanSnapshot(
      fetchPage: (_, _) async =>
          Either.right([posts.first, ...posts].toResult()),
    );
    expect(result, LoadedSearchSnapshot(posts));
  });

  for (final c in [
    (name: 'an unknown upload time', posts: [TestSearchPost(1, null)]),
    (
      name: 'non-chronological results',
      posts: [
        TestSearchPost(1, uploadedAt),
        TestSearchPost(2, uploadedAt.add(const Duration(seconds: 1))),
      ],
    ),
  ]) {
    test('rejects a snapshot with ${c.name}', () async {
      final result = await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.right(c.posts.toResult()),
      );
      expect(
        result,
        const FailedSearchScan(SearchRefreshErrorKind.unsupported),
      );
    });
  }

  test('normalizes timezone offsets when validating upload order', () async {
    final posts = [
      TestSearchPost(2, DateTime.parse('2026-09-14T12:00:00+02:00')),
      TestSearchPost(1, DateTime.parse('2026-09-14T11:00:00+02:00')),
    ];
    expect(
      await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.right(posts.toResult()),
      ),
      LoadedSearchSnapshot(posts),
    );
  });

  test('accepts an empty snapshot without requesting later pages', () async {
    var calls = 0;
    final result = await ChronologicalSearchScanner().scanSnapshot(
      fetchPage: (_, _) async {
        calls++;
        return Either.right(PostResult.empty());
      },
    );
    expect(calls, 1);
    expect(result, const LoadedSearchSnapshot([]));
  });

  test('returns a failed fetch without a usable snapshot', () async {
    expect(
      await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.left(SearchRefreshErrorKind.network),
      ),
      const FailedSearchScan(SearchRefreshErrorKind.network),
    );
  });
}
