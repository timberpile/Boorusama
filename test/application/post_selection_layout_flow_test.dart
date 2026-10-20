import 'package:boorusama/core/search/search/src/widgets/raw_search_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/posts/listing/src/types/page_mode.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_selection_controls.dart';
import 'package:boorusama/core/search/search/src/types/search_bar_position.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/selected_tag_chip.dart';
import 'package:boorusama/core/settings/types.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final position in SearchBarPosition.values) {
    for (final mode in PageMode.values) {
      testWidgets(
        'selection preserves $position search and $mode layout with large text and keyboard',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final backend = FakeBooruBackend();
          final harness = await HeadlessAppHarness.mount(
            tester,
            booruBackend: backend,
            phone: TestPhone.smallPortrait,
            runtime: backend.createRuntime(
              settings: Settings.defaultSettings.copyWith(
                searchBarPosition: position,
                reduceAnimations: true,
                listing: Settings.defaultSettings.listing.copyWith(
                  pageMode: mode,
                ),
              ),
            ),
          );
          await harness.pumpUntilFound(tester, postTile(101));
          final driver = AppFlowDriver(tester: tester, harness: harness);
          await driver.openSearch();
          await driver.submitSearch('cat');
          await harness.pumpUntilFound(tester, postTile(101));
          await harness.settle(tester);
          await tester.ensureVisible(postTile(101));
          await harness.settle(tester);
          expect(find.byType(SearchAppBar), findsOneWidget);
          final scroll = tester
              .state<ScrollableState>(postGridScrollable())
              .position;
          final before = scroll.pixels;
          final region = tester.getRect(find.byType(RawSearchRegion));
          final viewport = tester.getRect(postGridScrollable());
          final visible = Rect.fromLTRB(
            viewport.left,
            position == SearchBarPosition.top ? region.bottom : viewport.top,
            viewport.right,
            position == SearchBarPosition.bottom ? region.top : viewport.bottom,
          );
          final target = tester.getRect(postTile(101)).intersect(visible);
          expect(target.height, greaterThan(0));
          await tester.longPressAt(target.center);
          await harness.settle(tester);
          expect(scroll.pixels, before);
          expect(find.byType(SearchAppBar), findsOneWidget);
          expect(find.byType(SelectedTagChip), findsWidgets);
          expect(find.byType(PostSelectionControls), findsOneWidget);
          expect(tester.takeException(), isNull);
          final field = find.descendant(
            of: find.byType(SearchAppBar),
            matching: find.byType(EditableText),
          );
          await tester.showKeyboard(field);
          await harness.settle(tester);
          expect(harness.keyboard.isShown, isTrue);
          expect(find.byType(PostSelectionControls), findsOneWidget);
          expect(
            tester.getRect(find.byType(PostSelectionControls)).bottom,
            lessThanOrEqualTo(harness.keyboard.visibleArea.bottom),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
