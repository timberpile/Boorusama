import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'topic_test_utils.dart';

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
          testSearchPost(2, uploadedAt),
          testSearchPost(1, uploadedAt),
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
        for (var id = 100; id > 0; id--) testSearchPost(id, uploadedAt),
        testSearchPost(0, null),
      ];
      final result = await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.right(posts.toResult()),
      );
      expect((result as LoadedSearchSnapshot).posts.map((post) => post.id), [
        for (var id = 100; id > 50; id--) id,
      ]);
    },
  );

  test('uses a site limit and walks bounded full delta pages', () async {
    final seen = <(int, int)>[];
    final result = await ChronologicalSearchScanner().scanSnapshot(
      requestLimit: 100,
      maxPages: 3,
      fetchPage: (page, limit) async {
        seen.add((page, limit));
        final count = page == 3 ? 12 : 100;
        return Either.right(
          PostResult(
            total: null,
            posts: [
              for (var index = 0; index < count; index++)
                testSearchPost(1000 - ((page - 1) * 100 + index), uploadedAt),
            ],
            hasMore: page < 3,
          ),
        );
      },
    );
    expect(seen, [(1, 100), (2, 100), (3, 100)]);
    final posts = (result as LoadedSearchSnapshot).posts;
    expect(posts, hasLength(212));
    expect(posts.first.id, 1000);
    expect(posts.last.id, 789);
  });

  test('a later-page failure preserves the atomic snapshot contract', () async {
    final result = await ChronologicalSearchScanner().scanSnapshot(
      requestLimit: 100,
      maxPages: 3,
      fetchPage: (page, _) async => page == 1
          ? Either.right(
              PostResult(
                total: null,
                posts: [
                  for (var id = 200; id > 100; id--)
                    testSearchPost(id, uploadedAt),
                ],
                hasMore: true,
              ),
            )
          : Either.left(SearchRefreshErrorKind.network),
    );
    expect(result, const FailedSearchScan(SearchRefreshErrorKind.network));
  });

  test(
    'reports a lower bound when a full response is cut off by the budget',
    () async {
      final result = await ChronologicalSearchScanner().scanSnapshot(
        requestLimit: 2,
        fetchPage: (_, limit) async => Either.right(
          PostResult(
            total: null,
            posts: [
              testSearchPost(3, uploadedAt),
              testSearchPost(2, uploadedAt),
            ],
            hasMore: true,
          ),
        ),
      );
      expect((result as LoadedSearchSnapshot).truncated, isTrue);
    },
  );

  test('keeps distinct posts with equal timestamps in a snapshot', () async {
    final posts = [
      testSearchPost(2, uploadedAt),
      testSearchPost(1, uploadedAt),
    ];
    final result = await ChronologicalSearchScanner().scanSnapshot(
      fetchPage: (_, _) async =>
          Either.right([posts.first, ...posts].toResult()),
    );
    expect(result, LoadedSearchSnapshot(posts));
  });

  test('rejects a snapshot with an unknown upload time', () async {
    final result = await ChronologicalSearchScanner().scanSnapshot(
      fetchPage: (_, _) async =>
          Either.right([testSearchPost(1, null)].toResult()),
    );
    expect(result, const FailedSearchScan(SearchRefreshErrorKind.unsupported));
  });

  test('keeps site order when upload timestamps differ slightly', () async {
    final posts = [
      testSearchPost(2, uploadedAt),
      testSearchPost(1, uploadedAt.add(const Duration(seconds: 1))),
    ];
    expect(
      await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.right(posts.toResult()),
      ),
      LoadedSearchSnapshot(posts),
    );
  });

  test('keeps posts with upload times in different timezones', () async {
    final posts = [
      testSearchPost(2, DateTime.parse('2026-09-14T12:00:00+02:00')),
      testSearchPost(1, DateTime.parse('2026-09-14T11:00:00+02:00')),
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
