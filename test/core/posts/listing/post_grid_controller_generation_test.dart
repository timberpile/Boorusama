import 'dart:async';

import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  for (final failOld in [false, true]) {
    test('obsolete load completion cannot change a refreshed list: $failOld', () async {
      final oldStarted = Completer<void>();
      final oldResponse = Completer<PostResult<Post>>();
      final newerStarted = Completer<void>();
      final newerResponse = Completer<PostResult<Post>>();
      var refreshes = 0;
      var loads = 0;
      final controller = _controller((page) {
        if (page == 1) return Future.value(_page(++refreshes == 1 ? 1 : 10));
        loads++;
        if (loads == 1) {
          oldStarted.complete();
          return oldResponse.future;
        }
        newerStarted.complete();
        return newerResponse.future;
      });
      await controller.refresh();
      final obsolete = controller.fetchMore();
      await oldStarted.future;
      await controller.refresh();
      await obsolete;
      final newer = controller.fetchMore();
      await newerStarted.future;
      if (failOld) {
        oldResponse.completeError(StateError('obsolete failure'));
      } else {
        oldResponse.complete(_page(2));
      }
      // Drain the completed old chain without releasing the new network result.
      await Future<void>.delayed(Duration.zero);
      expect(controller.loading, isTrue);
      expect(controller.page, 2);
      expect(controller.items.map((post) => post.id), [10]);
      expect(controller.errors.value, isNull);
      expect(identical(controller.fetchMore(), newer), isTrue);
      newerResponse.complete(_page(11, more: false));
      await newer;
      expect(controller.items.map((post) => post.id), [10, 11]);
      expect(controller.loading, isFalse);
      expect(controller.hasMore, isFalse);
    });
  }

  test(
    'refresh cancels a queued debounce before it issues a page request',
    () async {
      final pages = <int>[];
      final controller = _controller((page) async {
        pages.add(page);
        return _page(pages.length);
      }, debounce: const Duration(days: 1));
      await controller.refresh();
      final queued = controller.fetchMore();
      await controller.refresh();
      await queued;
      expect(pages, [1, 1]);
      expect(controller.page, 1);
      expect(controller.loadingMore, isFalse);
    },
  );

  test(
    'failed initial load retries page one rather than skipping it',
    () async {
      final pages = <int>[];
      final controller = _controller((page) async {
        pages.add(page);
        if (pages.length == 1) throw StateError('offline');
        return _page(page);
      });
      await controller.refresh();
      expect(controller.errors.value, isNotNull);
      await controller.fetchMore();
      expect(pages, [1, 1]);
      expect(controller.errors.value, isNull);
      await controller.fetchMore();
      expect(pages, [1, 1, 2]);
    },
  );

  test('next-page navigation cannot skip a failed paginated page', () async {
    final pages = <int>[];
    var fail = true;
    final controller = _controller((page) async {
      pages.add(page);
      if (page == 2 && fail) throw StateError('offline');
      return _page(page);
    }, pageMode: PageMode.paginated);
    await controller.refresh();
    await controller.goToNextPage();
    expect(controller.page, 2);
    expect(controller.errors.value, isNotNull);
    expect(controller.hasNextPage(), isFalse);
    await controller.goToNextPage();
    expect(pages, [1, 2]);
    fail = false;
    await controller.fetchMore();
    expect(pages, [1, 2, 2]);
    expect(controller.items.single.id, 2);
    expect(controller.hasNextPage(), isTrue);
  });

  test(
    'disposing an in-flight load releases its waiter and ignores its result',
    () async {
      final started = Completer<void>();
      final response = Completer<PostResult<Post>>();
      var mounted = true;
      final controller = PostGridController<Post>(
        fetcher: (page) => TaskEither.tryCatch(() {
          if (page == 1) return Future.value(_page(1));
          started.complete();
          return response.future;
        }, (error, _) => UnknownError(error: error, message: error.toString())),
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => mounted,
        duplicateTracker: PostDuplicateTracker<Post>(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );
      await controller.refresh();
      final pending = controller.fetchMore();
      await started.future;
      mounted = false;
      controller.dispose();
      await pending;
      response.complete(_page(2));
      await Future<void>.delayed(Duration.zero);
      expect(controller.allItems.map((post) => post.id), [1]);
    },
  );

  test(
    'known terminal total wins over a larger independent search cap',
    () async {
      final controller = _controller(
        (_) async => PostResult<Post>(
          posts: [TestPost(id: 1)],
          total: 1,
          maxPage: 999,
        ),
      );
      await controller.refresh();
      expect(controller.hasMore, isFalse);
    },
  );

  test(
    'explicit continuation remains authoritative over zero total and cap',
    () async {
      final controller = _controller(
        (_) async => const PostResult<Post>(
          posts: [],
          total: 0,
          maxPage: 1,
          hasMore: true,
        ),
      );
      await controller.refresh();
      expect(controller.hasMore, isTrue);
    },
  );

  test(
    'obsolete ingestion cannot publish after waiting on blacklist URLs',
    () async {
      final oldFilterStarted = Completer<void>();
      final oldFilter = Completer<Set<String>>();
      var filters = 0;
      var refreshes = 0;
      final controller = _controller(
        (page) async => _page(page == 1 ? (++refreshes == 1 ? 1 : 10) : 2),
        urls: () {
          if (++filters == 2) {
            oldFilterStarted.complete();
            return oldFilter.future;
          }
          return Future.value(const <String>{});
        },
      );
      await controller.refresh();
      final obsolete = controller.fetchMore();
      await oldFilterStarted.future;
      await controller.refresh();
      oldFilter.complete({''});
      await obsolete;
      await Future<void>.delayed(Duration.zero);
      expect(controller.items.map((post) => post.id), [10]);
      expect(controller.page, 1);
      expect(controller.errors.value, isNull);
    },
  );
}

PostResult<Post> _page(int id, {bool more = true}) => PostResult(
  posts: [TestPost(id: id)],
  total: null,
  hasMore: more,
);

PostGridController<Post> _controller(
  Future<PostResult<Post>> Function(int) fetch, {
  Duration debounce = Duration.zero,
  Future<Set<String>> Function()? urls,
  PageMode pageMode = PageMode.infinite,
}) {
  final controller = PostGridController<Post>(
    fetcher: (page) => TaskEither.tryCatch(
      () => fetch(page),
      (error, _) => UnknownError(error: error, message: error.toString()),
    ),
    blacklistedTagsFetcher: () async => const {},
    blacklistedUrlsFetcher: urls,
    mountedChecker: () => true,
    duplicateTracker: PostDuplicateTracker<Post>(),
    onError: (_) {},
    debounceDuration: debounce,
    pageMode: pageMode,
  );
  addTearDown(controller.dispose);
  return controller;
}
