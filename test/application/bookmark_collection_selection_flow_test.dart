import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';

import 'support/app_flow_finders.dart';
import 'support/headless_app_harness.dart';

void main() {
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
