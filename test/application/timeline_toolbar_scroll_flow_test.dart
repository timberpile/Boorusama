import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/danbooru/home/src/latest_posts_view.dart';
import 'package:boorusama/boorus/danbooru/tags/trending/providers.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/home/src/widgets/home_search_bar.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_list_configuration_header.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final danbooru in [false, true]) {
    testWidgets(
      'Browse auto-hide moves both rows at the drag speed, Danbooru $danbooru',
      (tester) async {
        final backend = FakeBooruBackend();
        backend.posts
          ..clear()
          ..addAll(testPostRange(1, 120));
        final harness = await HeadlessAppHarness.mount(
          tester,
          runtime: backend.createRuntime(),
          booruBackend: backend,
          viewportSize: const Size(360, 844),
          additionalOverrides: [
            if (danbooru) ...[
              booruBuilderProvider.overrideWith((_, _) => DanbooruBuilder()),
              trendingTagsProvider.overrideWith((_, _) => Future.value([])),
            ],
          ],
        );
        await harness.pumpUntilFound(tester, postTile(1));
        expect(
          find.byType(LatestView),
          danbooru ? findsOneWidget : findsNothing,
        );
        final scrollable = postGridScrollable();
        final position = tester.state<ScrollableState>(scrollable).position;
        final search = find.byType(HomeSearchBar);
        final toolbar = find.byType(PostListConfigurationHeader);

        await tester.drag(scrollable, const Offset(0, -600));
        await harness.settle(tester);
        expect(position.pixels, greaterThan(300));
        await tester.drag(scrollable, const Offset(0, 45));
        await harness.settle(tester);
        expect(search.hitTestable(), findsOneWidget);
        expect(toolbar.hitTestable(), findsOneWidget);

        final drag = await tester.startGesture(const Offset(180, 420));
        await drag.moveBy(const Offset(0, -20));
        await tester.pump();
        final searchY = tester.getTopLeft(search).dy;
        final toolbarY = tester.getTopLeft(toolbar).dy;
        final pixels = position.pixels;
        await drag.moveBy(const Offset(0, -24));
        await tester.pump();
        expect(position.pixels - pixels, closeTo(24, .01));
        expect(tester.getTopLeft(search).dy - searchY, closeTo(-24, .01));
        expect(tester.getTopLeft(toolbar).dy - toolbarY, closeTo(-24, .01));
        await drag.moveBy(const Offset(0, 12));
        await tester.pump();
        expect(position.pixels - pixels, closeTo(12, .01));
        expect(tester.getTopLeft(search).dy - searchY, closeTo(-12, .01));
        expect(tester.getTopLeft(toolbar).dy - toolbarY, closeTo(-12, .01));
        await drag.up();
        await harness.settle(tester);
      },
    );
  }

  for (final pinned in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'populated timeline below Search stays reachable: pinned $pinned, scale $scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final backend = FakeBooruBackend();
          backend.posts
            ..clear()
            ..addAll(testPostRange(1, 120));
          const settings = Settings.defaultSettings;
          final harness = await HeadlessAppHarness.mount(
            tester,
            runtime: backend.createRuntime(
              settings: settings.copyWith(
                listing: settings.listing.copyWith(
                  keepTimelineToolbarVisible: pinned,
                ),
              ),
            ),
            booruBackend: backend,
            viewportSize: const Size(320, 844),
          );
          await harness.pumpUntilFound(tester, postTile(1));
          await harness.settle(tester);
          final header = find.byType(
            PostListConfigurationHeader,
            skipOffstage: false,
          );
          expect(header.hitTestable(), findsOneWidget);
          final ids = loadedPostIds(tester);
          for (var i = 0; i < 3; i++) {
            await tester.drag(postGridScrollable(), const Offset(0, -600));
            await harness.settle(tester);
          }
          final position = tester
              .state<ScrollableState>(postGridScrollable())
              .position;
          expect(position.pixels, greaterThan(1000));
          expect(header.hitTestable(), pinned ? findsOneWidget : findsNothing);

          for (var cycle = 0; cycle < 2; cycle++) {
            await tester.drag(postGridScrollable(), const Offset(0, 40));
            await harness.settle(tester);
            expect(position.pixels, greaterThan(1000));
            expect(header.hitTestable(), findsOneWidget);
            expect(
              tester.getTopLeft(header).dy,
              greaterThanOrEqualTo(
                tester.getBottomLeft(find.byType(HomeSearchBar)).dy,
              ),
            );
            expect(loadedPostIds(tester), ids);
            if (!pinned) {
              await tester.drag(postGridScrollable(), const Offset(0, -120));
              await harness.settle(tester);
              expect(header.hitTestable(), findsNothing);
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
