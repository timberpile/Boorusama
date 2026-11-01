import 'package:boorusama/core/home/src/widgets/home_search_bar.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_list_configuration_header.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_header_sliver.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
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
          final settings = Settings.defaultSettings;
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
          final header = find.descendant(
            of: find.byType(TimelineHeaderSliver, skipOffstage: false).first,
            matching: find.byType(
              PostListConfigurationHeader,
              skipOffstage: false,
            ),
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
