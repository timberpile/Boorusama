import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_config_icon_button.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'real View Options follows a navigation snap without shifting its grid',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: FakeBooruBackend(),
        viewportSize: const Size(320, 844),
      );
      await harness.pumpUntilFound(
        tester,
        find.byType(SliverPostGridImageGridItem),
      );
      final shell = tester.element(find.byType(AppNavigationShell));
      final chrome = ProviderScope.containerOf(shell)
          .read(navigationChromeProvider.notifier);
      final grid = find.byType(SliverPostGridImageGridItem).first;
      final initial = tester.getRect(grid);
      await tester.tap(
        find.descendant(
          of: find.byType(PostGridConfigIconButton),
          matching: find.byType(KurumiPopupMenuButton),
        ),
      );
      await harness.pumpUntilFound(
        tester,
        find.text(appStrings(tester).posts.actions.view_options),
      );
      await tester.tap(
        find.text(appStrings(tester).posts.actions.view_options),
      );
      await harness.pumpUntilFound(tester, find.byType(PostGridActionSheet));
      final sheet = find.byType(KurumiBottomSheet);
      await harness.pumpUntil(
        tester,
        () =>
            ModalRoute.of(tester.element(sheet))!.animation!.status ==
            AnimationStatus.completed,
        description: 'View Options route animation to finish',
      );
      final shown = MediaQuery.paddingOf(tester.element(sheet)).bottom;
      expect(shown, greaterThanOrEqualTo(64));
      chrome.userScroll(
        delta: shown,
        pixels: 300,
        outOfRange: false,
        extent: shown,
      );
      await tester.pump();
      final hidden = MediaQuery.paddingOf(tester.element(sheet)).bottom;
      expect(hidden, lessThan(shown));
      expect(tester.getRect(grid), initial);
      chrome.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final intermediate = MediaQuery.paddingOf(tester.element(sheet)).bottom;
      expect(intermediate, greaterThan(hidden));
      expect(intermediate, lessThan(shown));
      await tester.pump(const Duration(milliseconds: 80));
      expect(MediaQuery.paddingOf(tester.element(sheet)).bottom, shown);
      expect(tester.getRect(grid), initial);
      expect(tester.takeException(), isNull);
    },
  );
}
