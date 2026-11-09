import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter/rendering.dart' show CacheExtentStyle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final layout in ImageListType.values) {
    for (final size in [GridSize.micro, GridSize.normal, GridSize.large]) {
      testWidgets('shared $layout/$size thumbnails use the actual viewport', (
        tester,
      ) async {
        final backend = FakeBooruBackend();
        backend.posts
          ..clear()
          ..addAll(testPostRange(1, 400));
        final settings = Settings.defaultSettings;
        final harness = await HeadlessAppHarness.mount(
          tester,
          runtime: backend.createRuntime(
            settings: settings.copyWith(
              listing: settings.listing.copyWith(
                gridSize: size,
                imageListType: layout,
                postsPerPage: 200,
              ),
            ),
          ),
          booruBackend: backend,
          viewportSize: const Size(320, 844),
        );
        await harness.pumpUntilFound(tester, postTile(1));
        await harness.settle(tester);
        _expectViewportCache(tester);

        final initialViewport = tester
            .state<ScrollableState>(postGridScrollable())
            .position
            .viewportDimension;
        tester.view.physicalSize = const Size(320, 600);
        await harness.settle(tester);
        expect(
          tester
              .state<ScrollableState>(postGridScrollable())
              .position
              .viewportDimension,
          lessThan(initialViewport),
        );
        _expectViewportCache(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _expectViewportCache(WidgetTester tester) {
  final scrollView = tester.widget<CustomScrollView>(
    find
        .descendant(
          of: postGrid().first,
          matching: find.byType(CustomScrollView),
        )
        .first,
  );
  expect(scrollView.scrollCacheExtent?.style, CacheExtentStyle.viewport);
  expect(scrollView.scrollCacheExtent?.value, 1);

  final viewport = tester.getRect(postGridScrollable());
  final tiles = find.descendant(
    of: postGrid().first,
    matching: find.byWidgetPredicate(
      (widget) => widget is SliverPostGridImageGridItem,
      skipOffstage: false,
    ),
    // Sliver onstage traversal excludes children laid out only in the cache.
    // Those offscreen children are exactly the behavior asserted here.
    skipOffstage: false,
  );
  final ahead = tiles.evaluate().where(
    (element) =>
        tester
            .getRect(find.byWidget(element.widget, skipOffstage: false))
            .top >=
        viewport.bottom,
  );
  expect(ahead, isNotEmpty, reason: 'Prepare thumbnails before visibility.');
  expect(tiles.evaluate().length, lessThan(loadedPostIds(tester).length));
}
