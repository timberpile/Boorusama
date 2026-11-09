import 'dart:async';

import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/listing/src/types/page_mode.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_prefetch.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  testWidgets('starts at two remaining viewports and coalesces requests', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 100, more: true);
    expect(h.pages, [1]);
    final position = h.scroll.position;
    final threshold = position.maxScrollExtent - position.viewportDimension * 2;
    h.scroll.jumpTo(threshold - 1);
    await h.advance(tester);
    expect(h.pages, [1]);
    h.scroll.jumpTo(threshold);
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    h.scroll.jumpTo(threshold + 10);
    await h.advance(tester);
    expect(h.pages, [1, 2], reason: 'Do not overlap page requests.');
    await h.reply(tester, count: 100, more: true);
    expect(h.controller.items, hasLength(200));
    expect(
      position.extentAfter,
      greaterThan(position.viewportDimension * 2),
    );
    await h.advance(tester);
    expect(h.pages, [1, 2], reason: 'New content moves the end away.');
  });

  for (final count in [0, 1]) {
    testWidgets('bounds idle continuation for $count-post pages', (
      tester,
    ) async {
      final h = _Harness();
      await h.mount(tester);
      for (var page = 1; page <= 4; page++) {
        expect(h.pages.last, page);
        await h.reply(tester, count: count, more: true);
        await h.advance(tester);
      }
      expect(h.pages, [1, 2, 3, 4]);
      expect(h.controller.hasMore, isTrue);
      // Layout changes are not renewed permission to scan an unbounded feed.
      h.height.value = 500;
      await h.advance(tester);
      h.height.value = 450;
      await h.advance(tester);
      expect(h.pages, [1, 2, 3, 4]);
      final manual = h.controller.fetchMore();
      await h.advance(tester);
      expect(h.pages, [1, 2, 3, 4, 5]);
      await h.reply(tester, count: 1, more: false);
      await manual;
      await h.advance(tester);
      expect(h.pages, [1, 2, 3, 4, 5]);
      expect(h.controller.hasMore, isFalse);
    });
  }

  testWidgets('programmatic scrolling renews an exhausted fill cycle', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    for (var page = 1; page <= 4; page++) {
      await h.reply(tester, count: page == 1 ? 6 : 0, more: true);
      await h.advance(tester);
    }
    expect(h.pages, [1, 2, 3, 4]);
    h.scroll.jumpTo(10);
    await h.advance(tester);
    expect(h.pages, [1, 2, 3, 4, 5]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('empty continuation stops on a nonempty terminal page', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 0, more: true);
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    expect(h.controller.items, hasLength(1));
    expect(h.controller.hasMore, isFalse);
  });

  testWidgets('failure stops automatic retries and explicit retry keeps page', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    h.responses.last.completeError(StateError('Synthetic page failure'));
    await h.advance(tester);
    expect(h.controller.errors.value, isNotNull);
    expect(h.controller.page, 1);
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    final manual = h.controller.fetchMore();
    await h.advance(tester);
    expect(h.pages, [1, 2, 2]);
    await h.reply(tester, count: 1, more: false);
    await manual;
    expect(h.controller.errors.value, isNull);
  });

  testWidgets('refresh renews the bounded layout fill cycle', (tester) async {
    final h = _Harness();
    await h.mount(tester);
    for (var page = 1; page <= 4; page++) {
      await h.reply(tester, count: 0, more: true);
      await h.advance(tester);
    }
    expect(h.pages, [1, 2, 3, 4]);
    final refreshed = h.controller.refresh();
    await tester.pump();
    expect(h.pages.last, 1);
    await h.reply(tester, count: 0, more: true);
    await refreshed;
    await h.advance(tester);
    expect(h.pages, [1, 2, 3, 4, 1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('paginated mode never auto-advances', (tester) async {
    final h = _Harness(pageMode: PageMode.paginated);
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    await h.advance(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await h.advance(tester);
    expect(h.pages, [1]);
    expect(h.controller.hasNextPage(), isTrue);
  });

  testWidgets('inactive destination cannot start or dispatch queued work', (
    tester,
  ) async {
    final h = _Harness();
    h.active.value = false;
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    await h.advance(tester);
    expect(h.pages, [1]);
    h.active.value = true;
    await tester.pump();
    expect(h.controller.loadingMore, isTrue);
    h.active.value = false;
    await h.advance(tester);
    expect(h.pages, [1]);
    expect(h.controller.loadingMore, isFalse);
    expect(h.controller.page, 1);
    expect(h.controller.errors.value, isNull);
    h.active.value = true;
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('a covering route stops a queued request until return', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    expect(h.controller.loadingMore, isTrue);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await h.advance(tester);
    expect(h.pages, [1]);
    navigator.pop();
    await tester.pumpAndSettle();
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('backgrounding during debounce prevents network dispatch', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await h.advance(tester);
    expect(h.pages, [1]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('viewport growth rechecks distance without a scroll event', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 30, more: true);
    expect(h.pages, [1]);
    h.height.value = 1000;
    await tester.pump();
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('canceled dispatches retain the idle fill budget', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    for (var cancellation = 0; cancellation < 3; cancellation++) {
      expect(h.controller.loadingMore, isTrue);
      h.active.value = false;
      await h.advance(tester);
      expect(h.pages, [1]);
      h.active.value = true;
      await tester.pump();
    }
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('disposing the host prevents a queued request from dispatching', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(h.controller.debounceDuration);
    expect(h.pages, [1]);
    expect(h.controller.loadingMore, isFalse);
  });

  testWidgets('opted-out cached grids never continue until enabled', (
    tester,
  ) async {
    final h = _Harness();
    h.automatic.value = false;
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    await h.advance(tester);
    expect(h.pages, [1]);
    h.automatic.value = true;
    await h.advance(tester);
    expect(h.pages, [1, 2]);
    await h.reply(tester, count: 1, more: false);
  });

  testWidgets('manual continuation restarts the bounded fill budget', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    for (var page = 1; page <= 4; page++) {
      await h.reply(tester, count: 0, more: true);
      await h.advance(tester);
    }
    expect(h.pages, [1, 2, 3, 4]);
    final explicit = h.controller.fetchMore();
    await h.advance(tester);
    expect(h.pages, [1, 2, 3, 4, 5]);
    await h.reply(tester, count: 0, more: true);
    await explicit;
    for (var page = 6; page <= 8; page++) {
      await h.advance(tester);
      expect(h.pages.last, page);
      await h.reply(tester, count: 0, more: true);
    }
    await h.advance(tester);
    expect(h.pages, [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  testWidgets('explicit continuation promotes a pending automatic request', (
    tester,
  ) async {
    // A controller-only scenario avoids the automatic host scheduling a rival.
    final pages = <int>[];
    final controller = _controller((page) async {
      pages.add(page);
      return PostResult<Post>(
        posts: [TestPost(id: page)],
        total: null,
        hasMore: page == 1,
      );
    });
    addTearDown(controller.dispose);
    await controller.refresh();
    var allowed = true;
    final automatic = controller.fetchMore(canStart: () => allowed);
    allowed = false;
    final explicit = controller.fetchMore();
    expect(identical(automatic, explicit), isTrue);
    await tester.pump(controller.debounceDuration);
    await automatic;
    expect(pages, [1, 2]);
    expect(controller.hasMore, isFalse);
  });

  testWidgets(
    'promoting a host request permits exactly three more idle pages',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await h.reply(tester, count: 0, more: true);
      expect(h.controller.loadingMore, isTrue);
      final explicit = h.controller.fetchMore();
      await h.advance(tester);
      expect(h.pages, [1, 2]);
      await h.reply(tester, count: 0, more: true);
      await explicit;
      for (var page = 3; page <= 5; page++) {
        await h.advance(tester);
        expect(h.pages.last, page);
        await h.reply(tester, count: 0, more: true);
      }
      await h.advance(tester);
      expect(h.pages, [1, 2, 3, 4, 5]);
    },
  );

  testWidgets('switching to paginated mode revokes a queued continuation', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await h.reply(tester, count: 1, more: true);
    expect(h.controller.loadingMore, isTrue);
    h.controller.setPageMode(PageMode.paginated);
    await tester.pump();
    expect(h.pages, [1, 1]);
    await h.reply(tester, count: 1, more: true);
    await h.advance(tester);
    expect(h.pages, [1, 1]);
    expect(h.controller.hasNextPage(), isTrue);
  });
}

PostGridController<Post> _controller(
  Future<PostResult<Post>> Function(int) fetch, {
  PageMode pageMode = PageMode.infinite,
}) => PostGridController<Post>(
  fetcher: (page) => TaskEither.tryCatch(
    () => fetch(page),
    (error, _) => UnknownError(error: error, message: error.toString()),
  ),
  blacklistedTagsFetcher: () async => {},
  mountedChecker: () => true,
  duplicateTracker: PostDuplicateTracker<Post>(),
  onError: (_) {},
  pageMode: pageMode,
);

class _Harness {
  _Harness({PageMode pageMode = PageMode.infinite}) {
    controller = _controller((page) {
      pages.add(page);
      final response = Completer<PostResult<Post>>();
      responses.add(response);
      return response.future;
    }, pageMode: pageMode);
  }

  late final PostGridController<Post> controller;
  final scroll = ScrollController();
  final active = ValueNotifier(true);
  final automatic = ValueNotifier(true);
  final height = ValueNotifier(400.0);
  final pages = <int>[];
  final responses = <Completer<PostResult<Post>>>[];
  var _nextId = 1;

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      scroll.dispose();
      active.dispose();
      automatic.dispose();
      height.dispose();
      tester.view.reset();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    // Begin the initial page explicitly, as RawPostGrid does in production.
    unawaited(controller.refresh());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (_, extent, child) =>
                  SizedBox(height: extent, child: child),
              child: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, enabled, child) => NavigationActivity(
                  active: enabled,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: automatic,
                    builder: (_, allowed, inner) => PostGridPrefetch(
                      enabled: allowed,
                      controller: controller,
                      scrollController: scroll,
                      child: inner!,
                    ),
                    child: child!,
                  ),
                ),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => ListView.builder(
                    controller: scroll,
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemExtent: 100,
                    itemCount: controller.items.length,
                    // Unchanged fixed-size Text rows let Flutter skip layout
                    // after delegate growth; invalidate this fixture's geometry.
                    itemBuilder: (_, index) => Text(
                      'Post $index',
                      key: ValueKey((index, controller.items.length)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(pages, [1]);
  }

  Future<void> reply(
    WidgetTester tester, {
    required int count,
    required bool more,
  }) async {
    var completed = false;
    void observeCompletion() {
      if (!controller.loadingMore && !controller.refreshing) completed = true;
    }

    controller.addListener(observeCompletion);
    responses.last.complete(
      PostResult<Post>(
        posts: [for (var i = 0; i < count; i++) TestPost(id: _nextId++)],
        total: null,
        hasMore: more,
      ),
    );
    for (var frame = 0; frame < 20 && !completed; frame++) {
      await tester.pump();
    }
    controller.removeListener(observeCompletion);
    expect(completed, isTrue, reason: 'The controlled page must finish.');
    // Scroll metrics arrive after layout; let the host observe that frame.
    await tester.pump();
    await tester.pump();
  }

  Future<void> advance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(controller.debounceDuration);
  }
}
