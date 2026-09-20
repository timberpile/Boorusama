// Package imports:
import 'package:foundation/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';

void main() {
  final checkpoint = DateTime.utc(2026, 9);

  PostResult<Post> page(
    List<Post> posts, {
    int? total,
    int? maxPage,
    bool? hasMore,
  }) => PostResult(
    posts: posts,
    total: total ?? posts.length,
    maxPage: maxPage,
    hasMore: hasMore,
  );

  _TestPost post(int id, DateTime? createdAt) => _TestPost(
    id: id,
    createdAt: createdAt,
  );

  ChronologicalSearchScanner scanner({
    int pageSize = 2,
    Duration overlap = const Duration(minutes: 5),
  }) => ChronologicalSearchScanner(
    pageSize: pageSize,
    overlap: overlap,
  );

  test(
    'reads only the first page and keeps four previews for a baseline',
    () async {
      final fetchedPages = <int>[];
      final result = await scanner(pageSize: 7).scanBaseline(
        query: 'cat',
        fetchPage: (pageNumber, limit) async {
          fetchedPages.add(pageNumber);
          return Either.of(
            page([
              post(6, checkpoint.add(const Duration(minutes: 6))),
              post(5, checkpoint.add(const Duration(minutes: 5))),
              post(5, checkpoint.add(const Duration(minutes: 5))),
              post(4, checkpoint.add(const Duration(minutes: 4))),
              post(3, checkpoint.add(const Duration(minutes: 3))),
              post(2, checkpoint.add(const Duration(minutes: 2))),
              post(1, checkpoint.add(const Duration(minutes: 1))),
            ]),
          );
        },
      );

      expect(fetchedPages, [1]);
      expect(result, isA<CompletedSearchScan>());
      expect((result as CompletedSearchScan).posts.map((item) => item.id), [
        6,
        5,
        4,
        3,
      ]);
    },
  );

  test('continues until a page reaches the overlap boundary', () async {
    final fetchedPages = <int>[];
    final pages = {
      1: page([
        post(4, checkpoint.add(const Duration(days: 1))),
        post(3, checkpoint.add(const Duration(hours: 1))),
      ]),
      2: page([
        post(2, checkpoint.add(const Duration(minutes: 1))),
        post(1, checkpoint.subtract(const Duration(minutes: 5))),
      ]),
    };

    final result = await scanner().scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async {
        fetchedPages.add(pageNumber);
        return Either.of(pages[pageNumber]!);
      },
    );

    expect(fetchedPages, [1, 2]);
    expect(result, isA<CompletedSearchScan>());
    expect((result as CompletedSearchScan).posts.map((item) => item.id), [
      4,
      3,
      2,
    ]);
  });

  test('returns only posts strictly newer than the checkpoint', () async {
    final result = await scanner(pageSize: 3).scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async => Either.of(
        page([
          post(3, checkpoint.add(const Duration(seconds: 1))),
          post(2, checkpoint),
          post(1, checkpoint.subtract(const Duration(minutes: 5))),
        ]),
      ),
    );

    expect(result, isA<CompletedSearchScan>());
    expect((result as CompletedSearchScan).posts.map((item) => item.id), [3]);
  });

  test('returns duplicate IDs across pages once', () async {
    final pages = {
      1: page([
        post(3, checkpoint.add(const Duration(minutes: 3))),
        post(2, checkpoint.add(const Duration(minutes: 2))),
      ]),
      2: page([
        post(2, checkpoint.add(const Duration(minutes: 2))),
        post(1, checkpoint.add(const Duration(minutes: 1))),
      ]),
      3: page([post(0, checkpoint.subtract(const Duration(minutes: 5)))]),
    };

    final result = await scanner().scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async => Either.of(pages[pageNumber]!),
    );

    expect(result, isA<CompletedSearchScan>());
    expect((result as CompletedSearchScan).posts.map((item) => item.id), [
      3,
      2,
      1,
    ]);
  });

  final completedPages = [
    (name: 'an empty page', posts: <Post>[]),
    (name: 'a short page', posts: <Post>[post(1, checkpoint)]),
  ];
  for (final testCase in completedPages) {
    test('completes successfully for ${testCase.name}', () async {
      final result = await scanner().scanForNewPosts(
        query: 'cat',
        checkpoint: checkpoint,
        fetchPage: (pageNumber, limit) async => Either.of(
          page(testCase.posts),
        ),
      );

      expect(result, isA<CompletedSearchScan>());
    });
  }

  test('follows explicit continuation despite a short page', () async {
    final fetchedPages = <int>[];
    final result = await scanner(pageSize: 50).scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async {
        fetchedPages.add(pageNumber);
        return Either.of(
          switch (pageNumber) {
            1 => page([
              post(2, checkpoint.add(const Duration(minutes: 2))),
            ], hasMore: true),
            _ => page([
              post(1, checkpoint.subtract(const Duration(minutes: 5))),
            ], hasMore: false),
          },
        );
      },
    );

    expect(fetchedPages, [1, 2]);
    expect(result, isA<CompletedSearchScan>());
    expect((result as CompletedSearchScan).posts.map((item) => item.id), [2]);
  });

  test('honors the result maximum page', () async {
    final fetchedPages = <int>[];
    final result = await scanner().scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async {
        fetchedPages.add(pageNumber);
        return Either.of(
          page([
            post(2, checkpoint.add(const Duration(minutes: 2))),
            post(1, checkpoint.add(const Duration(minutes: 1))),
          ], maxPage: 1),
        );
      },
    );

    expect(fetchedPages, [1]);
    expect(result, isA<CompletedSearchScan>());
  });

  test('fails when the maximum page leaves known results unscanned', () async {
    final fetchedPages = <int>[];
    final result = await scanner().scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async {
        fetchedPages.add(pageNumber);
        return Either.of(
          page(
            [
              post(3, checkpoint.add(const Duration(minutes: 3))),
              post(2, checkpoint.add(const Duration(minutes: 2))),
            ],
            total: 3,
            maxPage: 1,
          ),
        );
      },
    );

    expect(fetchedPages, [1]);
    expect(
      result,
      const FailedSearchScan(SearchRefreshErrorKind.pagination),
    );
  });

  test('returns unsupported when a post timestamp is null', () async {
    final result = await scanner().scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async => Either.of(
        page([post(1, null)]),
      ),
    );

    expect(result, const FailedSearchScan(SearchRefreshErrorKind.unsupported));
  });

  final nonMonotonicPages = [
    (
      name: 'ascending timestamps within a page',
      pages: {
        1: page([
          post(1, checkpoint.add(const Duration(minutes: 1))),
          post(2, checkpoint.add(const Duration(minutes: 2))),
        ]),
      },
    ),
    (
      name: 'a newer timestamp on a later page',
      pages: {
        1: page([
          post(2, checkpoint.add(const Duration(minutes: 2))),
          post(1, checkpoint.add(const Duration(minutes: 1))),
        ]),
        2: page([
          post(3, checkpoint.add(const Duration(minutes: 2))),
          post(0, checkpoint.subtract(const Duration(minutes: 5))),
        ]),
      },
    ),
  ];
  for (final testCase in nonMonotonicPages) {
    test('returns unsupported for ${testCase.name}', () async {
      final result = await scanner().scanForNewPosts(
        query: 'cat',
        checkpoint: checkpoint,
        fetchPage: (pageNumber, limit) async => Either.of(
          testCase.pages[pageNumber]!,
        ),
      );

      expect(
        result,
        const FailedSearchScan(SearchRefreshErrorKind.unsupported),
      );
    });
  }

  test('returns a fetch failure without a partial success', () async {
    final result = await scanner(pageSize: 1).scanForNewPosts(
      query: 'cat',
      checkpoint: checkpoint,
      fetchPage: (pageNumber, limit) async => switch (pageNumber) {
        1 => Either.of(
          page([post(1, checkpoint.add(const Duration(minutes: 1)))]),
        ),
        _ => Either.left(SearchRefreshErrorKind.network),
      },
    );

    expect(result, const FailedSearchScan(SearchRefreshErrorKind.network));
  });
}

class _TestPost extends SimplePost {
  _TestPost({
    required super.id,
    required super.createdAt,
  }) : super(
         thumbnailImageUrl: '',
         sampleImageUrl: '',
         originalImageUrl: '',
         tags: const {},
         rating: Rating.general,
         hasComment: false,
         isTranslated: false,
         hasParentOrChildren: false,
         source: PostSource.none(),
         score: 0,
         duration: 0,
         fileSize: 0,
         format: 'jpg',
         hasSound: null,
         height: 0,
         md5: '',
         videoThumbnailUrl: '',
         videoUrl: '',
         width: 0,
         uploaderId: null,
         metadata: null,
       );
}
