import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/widgets/widgets.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';

import 'support/app_flow_finders.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final enlarged in [false, true]) {
    testWidgets(
      'removing the final selected bookmark closes selection (enlarged: $enlarged)',
      (tester) async {
        if (enlarged) {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final harness = await HeadlessAppHarness.mount(tester);
        await harness.pumpUntilFound(tester, postTile(102));
        final context = tester.element(postTile(101));
        final posts = postController(tester).items.toList();
        final notifier = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(bookmarkProvider.notifier);
        final result = await notifier.createGroupWithPosts(
          'Selection target',
          harness.booruBackend.config.auth,
          posts,
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                BookmarkPage(view: BookmarkView.group(result.group.id)),
          ),
        );
        await harness.settle(tester);
        await tester.longPress(postTile(101));
        await harness.settle(tester);
        await tester.tap(postTile(102));
        await harness.settle(tester);
        final selection = SelectionMode.of(tester.element(postTile(101)));
        expect(selection.selection, hasLength(2));
        await notifier.removePostsFromGroup(
          harness.booruBackend.config.auth,
          [posts.singleWhere((post) => post.id == 101)],
          result.group.id,
        );
        await harness.settle(tester);
        expect(selection.isActive, isTrue);
        expect(selection.selection, hasLength(1));
        expect(find.byType(MultiSelectionActionBar), findsOneWidget);
        if (enlarged) {
          await notifier.removePostsFromGroup(
            harness.booruBackend.config.auth,
            [posts.singleWhere((post) => post.id == 102)],
            result.group.id,
          );
        } else {
          await tester.tap(find.byType(MultiSelectPopupButton));
          await harness.settle(tester);
          await tester.tap(find.text(appStrings(tester).bookmark.bulk.remove));
          await harness.settle(tester);
          await tester.tap(find.text('Selection target'));
        }
        await harness.pumpUntil(tester, () => !selection.isActive);
        await harness.settle(tester);
        expect(find.byType(MultiSelectionActionBar), findsNothing);
        expect(find.text('0 items selected'), findsNothing);
        expect(find.byType(BookmarkPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        dismissAllToast();
        // Drain oktoast's scheduled fade through the widget's controlled clock.
        await tester.pump(const Duration(seconds: 5));
      },
    );
  }

  testWidgets(
    'bookmark folder/group drag skips system cards and Back exits the active selection',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(tester);
      await harness.pumpUntilFound(tester, postTile(101));
      final context = tester.element(postTile(101));
      final notifier = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(bookmarkProvider.notifier);
      await notifier.future;
      await notifier.createFolder('Folder');
      await notifier.createGroup('Alpha');
      await notifier.createGroup('Beta');
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BookmarkGroupBrowserPage(),
        ),
      );
      await harness.settle(tester);
      await tester.longPress(find.text('Folder'));
      await harness.settle(tester);
      expect(find.text('1 item selected'), findsOneWidget);
      final drag = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await drag.moveTo(
        tester.getCenter(
          find.text(appStrings(tester).bookmark.groups.default_group),
        ),
      );
      await tester.pump();
      expect(find.text('2 items selected'), findsOneWidget);
      await drag.moveTo(tester.getCenter(find.text('Beta')));
      await tester.pump();
      expect(find.text('3 items selected'), findsOneWidget);
      await drag.up();
      await harness.settle(tester);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
      expect(find.text('3 items selected'), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
    },
  );
}
