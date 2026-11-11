// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test(
    'initial paginated ordinal is used once, then refresh resets normally',
    () async {
      final pages = <int>[];
      final controller = PostGridController<Post>(
        fetcher: (page) {
          pages.add(page);
          return TaskEither.right(testPostResult([TestPost(id: page)]));
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        pageMode: PageMode.paginated,
        initialPage: 3,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.page, 3);
      await controller.refresh();
      expect(controller.page, 1);
      expect(pages, [3, 1]);
    },
  );

  test(
    'explicit refresh invalidates source while page navigation does not',
    () async {
      var invalidations = 0;
      final pages = <int>[];
      final controller = PostGridController<Post>(
        fetcher: (page) {
          pages.add(page);
          return TaskEither.right(testPostResult([TestPost(id: page)]));
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        pageMode: PageMode.paginated,
        onRefresh: () => invalidations++,
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.jumpToPage(3);
      expect(invalidations, 1);
      expect(pages, [1, 3]);
      await controller.refresh(maintainPage: true);
      expect(invalidations, 2);
      expect(pages, [1, 3, 3]);
    },
  );

  test('a refresh requested mid-fetch replaces the stale result', () async {
    final listing = _GatedListing();
    final controller = listing.controller;

    final firstRefresh = controller.refresh();
    listing.query = 'dog';
    final queuedRefresh = controller.refresh();
    await _settle();
    expect(listing.fetches, ['cat']);

    listing.complete(0, [TestPost(id: 1)]);
    await _settle();
    expect(listing.fetches, ['cat', 'dog']);
    expect(controller.allItems, isEmpty);
    expect(controller.refreshing, isTrue);

    listing.complete(1, [TestPost(id: 2)]);
    await Future.wait([firstRefresh, queuedRefresh]);
    expect(controller.allItems.map((post) => post.id), [2]);
    expect(controller.refreshing, isFalse);
  });

  test('several mid-fetch refresh requests cause one extra fetch', () async {
    final listing = _GatedListing();
    final controller = listing.controller;

    final firstRefresh = controller.refresh();
    for (final query in ['dog', 'fox', 'owl']) {
      listing.query = query;
      unawaited(controller.refresh());
    }

    listing.complete(0, [TestPost(id: 1)]);
    await _settle();
    listing.complete(1, [TestPost(id: 4)]);
    await firstRefresh;

    expect(listing.fetches, ['cat', 'owl']);
    expect(controller.allItems.map((post) => post.id), [4]);
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// A listing whose fetches stay pending until the test completes them.
final class _GatedListing {
  _GatedListing() {
    controller = PostGridController<Post>(
      fetcher: (page) {
        final completer = Completer<Either<BooruError, PostResult<Post>>>();
        fetches.add(query);
        _pending.add(completer);
        return TaskEither(() => completer.future);
      },
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
    );
    addTearDown(controller.dispose);
  }

  late final PostGridController<Post> controller;
  final fetches = <String>[];
  final _pending = <Completer<Either<BooruError, PostResult<Post>>>>[];
  var query = 'cat';

  void complete(int fetch, List<Post> posts) =>
      _pending[fetch].complete(Either.of(testPostResult(posts)));
}
