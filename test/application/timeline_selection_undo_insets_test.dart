import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_selection_controls.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';

import 'support/app_flow_driver.dart';

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
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openSearch();
        await driver.submitSearch('cat');
        await harness.pumpUntilFound(tester, postTile(101));
        await harness.settle(tester);
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
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is MultiSelectPopupButton &&
                widget.name == appStrings(tester).post.action.bookmark,
          ),
        );
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
        final field = find.descendant(
          of: find.byType(SearchAppBar),
          matching: find.byType(EditableText),
        );
        await tester.showKeyboard(field);
        await harness.settle(tester);
        expect(harness.keyboard.isShown, isTrue);
        expect(
          tester.getRect(manager).bottom,
          lessThanOrEqualTo(harness.keyboard.visibleArea.bottom),
        );
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
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await harness.settle(tester);
        expect(harness.keyboard.isShown, isFalse);
        await bookmarks.createGroup('Ordinary success');
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is MultiSelectPopupButton &&
                widget.name == appStrings(tester).post.action.bookmark,
          ),
        );
        await harness.settle(tester);
        await tester.tap(find.text(appStrings(tester).bookmark.bulk.add));
        await harness.settle(tester);
        await tester.ensureVisible(find.text('Ordinary success'));
        await harness.settle(tester);
        await tester.tap(find.text('Ordinary success'));
        final success = find.byKey(const ValueKey('kurumi-success-toast'));
        await harness.pumpUntilFound(tester, success);
        await harness.settle(tester);
        expect(
          container
              .read(bookmarkProvider)
              .requireValue
              .groups
              .firstWhere((group) => group.name == 'Ordinary success')
              .bookmarkIds,
          hasLength(1),
        );
        for (final keyboard in [false, true, false]) {
          if (keyboard) {
            await tester.showKeyboard(field);
          } else {
            tester.testTextInput.hide();
          }
          await harness.settle(tester);
          expect(harness.keyboard.isShown, keyboard);
          expect(
            tester.getRect(manager).top - tester.getRect(success).bottom,
            closeTo(16, .5),
          );
        }
        dismissAllToast(showAnim: false);
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
