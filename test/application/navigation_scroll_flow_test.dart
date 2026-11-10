import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart' as ui show Material, MaterialType, Theme;

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'navigation surface stays readable and moves entirely with the bar',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(
        tester,
        phone: TestPhone.portrait,
      );
      await harness.pumpUntilFound(tester, find.byType(PostGrid));
      await tester.tap(find.byKey(const Key('nav-shortcut-bookmarks')));
      await harness.pumpUntilFound(
        tester,
        find.byType(BookmarkGroupBrowserPage),
      );
      await harness.settle(tester);
      final shell = tester.element(find.byType(AppNavigationShell));
      final container = ProviderScope.containerOf(shell);
      final chrome = container.read(navigationChromeProvider.notifier);
      final extent =
          kNavigationBarHeight + MediaQuery.viewPaddingOf(shell).bottom;
      final scroll = find.descendant(
        of: find.byType(BookmarkGroupBrowserPage),
        matching: find.byType(CustomScrollView),
      );
      void verifyMovingSurface() {
        expect(
          tester.getRect(scroll).bottom,
          closeTo(MediaQuery.heightOf(shell), .01),
        );
        ui.Material? material;
        tester
            .element(find.byKey(const Key('nav-shortcut-browse')))
            .visitAncestorElements((element) {
              if (element.widget case final ui.Material surface) {
                material = surface;
                return false;
              }
              return true;
            });
        expect(material?.type, ui.MaterialType.canvas);
        expect(
          material?.color,
          ui.Theme.of(shell).colorScheme.surfaceContainer,
        );
        final translation = tester
            .widget<FractionalTranslation>(
              find.descendant(
                of: find.ancestor(
                  of: find.byKey(const Key('nav-shortcut-browse')),
                  matching: find.byType(AnimatedSlide),
                ),
                matching: find.byType(FractionalTranslation),
              ),
            )
            .translation
            .dy;
        expect(
          tester.getRect(find.byWidget(material!)).top,
          closeTo(
            MediaQuery.heightOf(shell) - extent + extent * translation,
            .01,
          ),
        );
      }

      double barOffset() {
        final slide = find.ancestor(
          of: find.byKey(const Key('nav-shortcut-browse')),
          matching: find.byType(AnimatedSlide),
        );
        return tester
            .widget<FractionalTranslation>(
              find.descendant(
                of: slide,
                matching: find.byType(FractionalTranslation),
              ),
            )
            .translation
            .dy;
      }

      verifyMovingSurface();
      chrome.userScroll(
        delta: extent * .6,
        pixels: 300,
        outOfRange: false,
        extent: extent,
      );
      await tester.pump();
      expect(barOffset(), closeTo(.6, .001));
      verifyMovingSurface();
      chrome.endScroll(pixels: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(barOffset(), allOf(greaterThan(.6), lessThan(1)));
      verifyMovingSurface();
      await harness.settle(tester);
      expect(container.read(navigationChromeProvider).barVisible, isFalse);
      verifyMovingSurface();
      chrome.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(barOffset(), allOf(greaterThan(0), lessThan(1)));
      verifyMovingSurface();
      await harness.settle(tester);
      verifyMovingSurface();
      expect(tester.takeException(), isNull);
    },
  );

  for (final indicator in [
    PageIndicatorPosition.top,
    PageIndicatorPosition.bottom,
  ]) {
    testWidgets(
      'paginated group final row clears transparent navigation with $indicator indicator',
      (tester) async {
        final backend = FakeBooruBackend()
          ..posts.addAll(testPostRange(103, 150));
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          phone: TestPhone.portrait,
          runtime: backend.createRuntime(
            settings: Settings.defaultSettings.copyWith(
              listing: Settings.defaultSettings.listing.copyWith(
                pageMode: PageMode.paginated,
                pageIndicatorPosition: indicator,
              ),
            ),
          ),
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final context = tester.element(postTile(101));
        final posts = postController(tester).items.toList();
        final library = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(bookmarkProvider.notifier);
        final result = await harness.pumpUntilComplete(
          tester,
          library.createGroupWithPosts(
            'Paging clearance',
            backend.config.auth,
            posts,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                BookmarkPage(view: BookmarkView.group(result.group.id)),
          ),
        );
        await harness.settle(tester);
        final controller = postController(tester);
        final last = postTile(controller.items.last.id);
        final position = tester
            .state<ScrollableState>(postGridScrollable())
            .position;
        position.jumpTo(position.maxScrollExtent);
        await harness.settle(tester);
        expect(last.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(last).bottom,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(const Key('nav-shortcut-browse'))).dy,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final travel in [20.0, 70.0]) {
    testWidgets(
      'held grid drag moves navigation pixel for pixel, travel=$travel',
      (tester) async {
        final backend = FakeBooruBackend()
          ..posts.addAll(testPostRange(103, 150));
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          phone: TestPhone.portrait,
        );
        await harness.pumpUntilFound(tester, find.byType(PostGrid));
        await harness.settle(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppNavigationShell)),
        );
        final scroll = tester
            .state<ScrollableState>(postGridScrollable())
            .position;
        scroll.jumpTo(300);
        await harness.settle(tester);
        final bar = find.byKey(const Key('nav-shortcut-browse'));
        final originalTop = tester.getTopLeft(bar).dy;
        expect(container.read(navigationChromeProvider).barHiddenFraction, 0);
        final gesture = await tester.startGesture(const Offset(200, 400));
        // Cross touch slop before comparing content and chrome displacement.
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump();
        final startPixels = scroll.pixels;
        final startTop = tester.getTopLeft(bar).dy;
        await gesture.moveBy(Offset(0, -travel));
        await tester.pump();
        final movedTop = tester.getTopLeft(bar).dy;
        expect(
          movedTop - startTop,
          closeTo(scroll.pixels - startPixels, 0.001),
        );
        expect(movedTop, greaterThan(originalTop));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getTopLeft(bar).dy, movedTop);
        // Direction changes take effect immediately, without a new threshold.
        final reversePixels = scroll.pixels;
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump();
        expect(
          tester.getTopLeft(bar).dy - movedTop,
          closeTo(scroll.pixels - reversePixels, 0.001),
        );
        await gesture.up();
        await harness.settle(tester);
        expect(
          container.read(navigationChromeProvider).barScrollActive,
          isFalse,
        );
        expect(
          container.read(navigationChromeProvider).barHiddenFraction,
          travel < 49 ? 0 : 1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
