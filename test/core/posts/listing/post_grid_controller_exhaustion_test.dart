import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/src/types/page_mode.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  for (final reason in ['explicit end', 'last page', 'known total']) {
    test('$reason stops after the first complete nonempty response', () async {
      final pages = <int>[];
      final controller = _controller((page) async {
        pages.add(page);
        return PostResult<Post>(
          posts: [TestPost(id: 1)],
          total: reason == 'known total' ? 1 : null,
          maxPage: reason == 'last page' ? 1 : null,
          hasMore: reason == 'explicit end' ? false : null,
        );
      });
      await controller.refresh();
      expect(controller.hasMore, isFalse);
      expect(controller.allItems.map((post) => post.id), [1]);
      await controller.fetchMore();
      expect(pages, [1]);
    });
  }

  test('the final page is ingested before stopping', () async {
    final controller = _controller(
      (page) async => PostResult<Post>(
        posts: [TestPost(id: page)],
        total: 2,
        hasMore: page < 2,
      ),
    );
    await controller.refresh();
    expect(controller.hasMore, isTrue);
    await controller.fetchMore();
    expect(controller.allItems.map((post) => post.id), [1, 2]);
    expect(controller.hasMore, isFalse);
  });

  test(
    'explicit continuation survives an empty filtered source page',
    () async {
      final controller = _controller(
        (page) async => PostResult<Post>(
          posts: page == 1 ? [] : [TestPost(id: 2)],
          total: null,
          hasMore: page == 1,
        ),
      );
      await controller.refresh();
      expect(controller.items, isEmpty);
      expect(controller.hasMore, isTrue);
      await controller.fetchMore();
      expect(controller.items.single.id, 2);
      expect(controller.hasMore, isFalse);
    },
  );

  test('local blacklist does not replace the source continuation', () async {
    final controller = _controller(
      (page) async => PostResult<Post>(
        posts: [
          TestPost(id: page, tags: {'blocked'}),
        ],
        total: 2,
        hasMore: page < 2,
      ),
      blacklist: {'blocked'},
    );
    await controller.refresh();
    expect(controller.items, isEmpty);
    expect(controller.hasMore, isTrue);
    await controller.fetchMore();
    expect(controller.allItems, hasLength(2));
    expect(controller.items, isEmpty);
    expect(controller.hasMore, isFalse);
  });

  test(
    'duplicate-only page without metadata is not proof of exhaustion',
    () async {
      final controller = _controller(
        (page) async => PostResult<Post>(
          posts: page < 3 ? [TestPost(id: 1)] : [],
          total: null,
        ),
      );
      await controller.refresh();
      await controller.fetchMore();
      expect(controller.allItems, hasLength(1));
      expect(controller.hasMore, isTrue);
      await controller.fetchMore();
      expect(controller.hasMore, isFalse);
    },
  );

  test(
    'a failed next-page request remains retryable on the same page',
    () async {
      var fail = true;
      final pages = <int>[];
      final controller = _controller((page) async {
        pages.add(page);
        if (page == 2 && fail) throw StateError('offline');
        return PostResult<Post>(
          posts: [TestPost(id: page)],
          total: null,
          hasMore: page < 2,
        );
      });
      await controller.refresh();
      await controller.fetchMore();
      expect(controller.errors.value, isNotNull);
      expect(controller.hasMore, isTrue);
      expect(controller.page, 1);
      fail = false;
      await controller.fetchMore();
      expect(pages, [1, 2, 2]);
      expect(controller.errors.value, isNull);
      expect(controller.hasMore, isFalse);
      expect(controller.items.map((post) => post.id), [1, 2]);
    },
  );

  test(
    'paginated final page remains visible and previous navigation works',
    () async {
      final controller = _controller(
        (page) async => PostResult<Post>(
          posts: [TestPost(id: page)],
          total: 2,
          maxPage: 2,
        ),
        pageMode: PageMode.paginated,
      );
      await controller.refresh();
      await controller.jumpToPage(2);
      expect(controller.items.single.id, 2);
      expect(controller.hasNextPage(), isFalse);
      expect(controller.hasPreviousPage(), isTrue);
      await controller.goToPreviousPage();
      expect(controller.items.single.id, 1);
      expect(controller.hasNextPage(), isTrue);
    },
  );
}

PostGridController<Post> _controller(
  Future<PostResult<Post>> Function(int) fetch, {
  Set<String> blacklist = const {},
  PageMode pageMode = PageMode.infinite,
}) {
  final controller = PostGridController<Post>(
    fetcher: (page) => TaskEither.tryCatch(
      () => fetch(page),
      (error, _) => UnknownError(error: error, message: error.toString()),
    ),
    blacklistedTagsFetcher: () async => blacklist,
    mountedChecker: () => true,
    duplicateTracker: PostDuplicateTracker<Post>(),
    onError: (_) {},
    debounceDuration: Duration.zero,
    pageMode: pageMode,
  );
  addTearDown(controller.dispose);
  return controller;
}
