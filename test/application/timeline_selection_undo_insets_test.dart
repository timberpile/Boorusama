import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_selection_controls.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:selection_mode/selection_mode.dart';

import 'support/app_flow_finders.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'timeline Undo clears the live selection manager at scale $scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = await HeadlessAppHarness.mount(
          tester,
          phone: TestPhone.smallPortrait,
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final container = ProviderScope.containerOf(
          tester.element(postTile(101)),
          listen: false,
        );
        final bookmarks = container.read(bookmarkProvider.notifier);
        final post = postController(tester).items
            .firstWhere((post) => post.id == 101);
        await bookmarks.createGroupWithPosts(
          'Timeline Undo',
          harness.booruBackend.config.auth,
          [post],
        );
        await tester.longPress(postTile(101));
        await harness.settle(tester);
        final selection = SelectionMode.of(tester.element(postTile(101)));
        expect(selection.isActive, isTrue);
        final manager = find.byType(PostSelectionControls);
        expect(manager, findsOneWidget);
        await tester.tap(find.byType(MultiSelectPopupButton));
        await harness.settle(tester);
        await tester.tap(find.text(appStrings(tester).bookmark.bulk.remove));
        await harness.settle(tester);
        await tester.ensureVisible(find.text('Timeline Undo'));
        await harness.settle(tester);
        await tester.tap(find.text('Timeline Undo'));
        final toast = find.byKey(const ValueKey('kurumi-action-toast'));
        await harness.pumpUntilFound(tester, toast);
        await harness.settle(tester);
        expect(selection.isActive, isTrue);
        expect(
          tester.getRect(toast).bottom,
          lessThanOrEqualTo(tester.getRect(manager).top - 8),
        );
        await tester.tap(find.text('Undo'));
        await harness.settle(tester);
        expect(
          container.read(bookmarkProvider).requireValue.bookmarks,
          hasLength(1),
        );
        expect(selection.isActive, isTrue);
        dismissAllToast(showAnim: false);
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
