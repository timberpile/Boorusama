// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_selection.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/errors/error.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/listing/src/types/page_mode.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  test(
    'a preserving refresh exposes its selection policy only while loading',
    () async {
      late PostGridController<Post> controller;
      var preservedDuringFetch = false;
      controller = PostGridController<Post>(
        fetcher: (_) {
          preservedDuringFetch = controller.preserveSelectionOnRefresh;
          return TaskEither.right(
            PostResult(
              posts: [Bookmark.empty.toPost()],
              total: 1,
            ),
          );
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.refresh(preserveSelection: true);

      expect(preservedDuringFetch, isTrue);
      expect(controller.preserveSelectionOnRefresh, isFalse);
    },
  );

  test('surviving bookmark selections are remapped by identity', () {
    final first = Bookmark.empty
        .copyWith(id: 1, originalUrl: 'https://example.com/first.jpg')
        .toPost();
    final second = Bookmark.empty
        .copyWith(id: 2, originalUrl: 'https://example.com/second.jpg')
        .toPost();
    final third = Bookmark.empty
        .copyWith(id: 3, originalUrl: 'https://example.com/third.jpg')
        .toPost();

    final identities = selectedBookmarkIdentities(
      [first, second, third],
      {
        0,
        2,
      },
    );
    final indices = bookmarkSelectionIndices([third, second], identities);

    expect(indices, [0]);
  });

  test(
    'a refresh requested while loading runs after the active refresh',
    () async {
      final firstFetch = Completer<PostResult<Post>>();
      var fetchCount = 0;
      final controller = PostGridController<Post>(
        fetcher: (_) {
          fetchCount++;
          return TaskEither.tryCatch(
            () => fetchCount == 1
                ? firstFetch.future
                : Future.value(PostResult.empty()),
            (error, _) => UnknownError(error: error, message: 'failed'),
          );
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      final activeRefresh = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      final queuedRefresh = controller.refresh();
      firstFetch.complete(PostResult.empty());
      await Future.wait([activeRefresh, queuedRefresh]);

      expect(fetchCount, 2);
    },
  );

  test('a failed refresh does not block the next refresh', () async {
    var fetchCount = 0;
    var blacklistCount = 0;
    final controller = PostGridController<Post>(
      fetcher: (_) {
        fetchCount++;
        return TaskEither.right(
          PostResult(posts: [Bookmark.empty.toPost()], total: 1),
        );
      },
      blacklistedTagsFetcher: () async => const {},
      blacklistedUrlsFetcher: () async {
        blacklistCount++;
        if (blacklistCount == 1) throw StateError('blacklist read failed');
        return const {};
      },
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    await expectLater(controller.refresh(), throwsStateError);
    expect(controller.refreshing, isFalse);

    await controller.refresh().timeout(const Duration(seconds: 1));

    expect(fetchCount, 2);
    expect(controller.refreshing, isFalse);
  });

  test('a queued refresh still runs after the active refresh fails', () async {
    final firstFetch = Completer<PostResult<Post>>();
    var fetchCount = 0;
    var blacklistCount = 0;
    final controller = PostGridController<Post>(
      fetcher: (_) {
        fetchCount++;
        return TaskEither.tryCatch(
          () => fetchCount == 1
              ? firstFetch.future
              : Future.value(
                  PostResult(posts: [Bookmark.empty.toPost()], total: 1),
                ),
          (error, _) => UnknownError(error: error, message: 'failed'),
        );
      },
      blacklistedTagsFetcher: () async => const {},
      blacklistedUrlsFetcher: () async {
        blacklistCount++;
        if (blacklistCount == 1) throw StateError('blacklist read failed');
        return const {};
      },
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    final active = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final queued = controller.refresh();
    firstFetch.complete(PostResult.empty());

    await expectLater(active, throwsStateError);
    await queued.timeout(const Duration(seconds: 1));
    expect(fetchCount, 2);
  });

  test('a queued page reset overrides page preservation', () async {
    final firstFetch = Completer<PostResult<Post>>();
    final fetchedPages = <int>[];
    final controller = PostGridController<Post>(
      initialPage: 5,
      pageMode: PageMode.paginated,
      fetcher: (page) {
        fetchedPages.add(page);
        return TaskEither.tryCatch(
          () => fetchedPages.length == 1
              ? firstFetch.future
              : Future.value(PostResult.empty()),
          (error, _) => UnknownError(error: error, message: 'failed'),
        );
      },
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    final active = controller.refresh(maintainPage: true);
    await Future<void>.delayed(Duration.zero);
    final preserving = controller.refresh(maintainPage: true);
    final resetting = controller.refresh();
    firstFetch.complete(PostResult.empty());
    await Future.wait([active, preserving, resetting]);

    expect(fetchedPages, [5, 1]);
  });

  test(
    'a refresh completes quietly after its controller is disposed',
    () async {
      final fetch = Completer<PostResult<Post>>();
      var mounted = true;
      final controller = PostGridController<Post>(
        fetcher: (_) => TaskEither.tryCatch(
          () => fetch.future,
          (error, _) => UnknownError(error: error, message: 'failed'),
        ),
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => mounted,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );

      final active = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      final queued = controller.refresh();
      mounted = false;
      controller.dispose();
      fetch.complete(PostResult.empty());

      await Future.wait([active, queued]);
    },
  );
}
