import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/navigation/app_navigation.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_selection_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';

import 'support/app_flow_finders.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'bookmark feedback excludes consumed keyboard inset at $scale',
      (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = await HeadlessAppHarness.mount(
          tester,
          phone: TestPhone.portrait,
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final context = tester.element(postTile(101));
        final container = ProviderScope.containerOf(context, listen: false);
        final result = await container
            .read(bookmarkProvider.notifier)
            .createGroupWithPosts(
              'Keyboard geometry',
              harness.booruBackend.config.auth,
              postController(tester).items,
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
        final manager = find.byType(PostSelectionControls);
        final field = find.descendant(
          of: find.byType(BookmarkSearchBar),
          matching: find.byType(EditableText),
        );
        for (final withAction in [false, true]) {
          var undone = 0;
          Kurumi.showSuccessToast(
            container.read(appNavigationProvider).feedbackKey.currentContext!,
            'Updated bookmarks',
            duration: Duration.zero,
            actionLabel: withAction ? 'Undo' : null,
            onAction: withAction ? () => undone++ : null,
          );
          final toast = find.byKey(
            ValueKey(
              withAction ? 'kurumi-action-toast' : 'kurumi-success-toast',
            ),
          );
          await harness.pumpUntilFound(tester, toast);
          for (final keyboard in [false, true, false]) {
            if (keyboard) {
              await tester.showKeyboard(field);
            } else {
              FocusManager.instance.primaryFocus?.unfocus();
              tester.testTextInput.hide();
            }
            await harness.settle(tester);
            expect(harness.keyboard.isShown, keyboard);
            // The actual Scaffold has already consumed the native keyboard.
            expect(MediaQuery.viewInsetsOf(tester.element(manager)).bottom, 0);
            expect(
              tester.getRect(manager).bottom,
              lessThanOrEqualTo(harness.keyboard.visibleArea.bottom),
            );
            expect(
              tester.getRect(manager).top - tester.getRect(toast).bottom,
              closeTo(16, .5),
            );
          }
          if (withAction) {
            await tester.tap(find.text('Undo'));
            await harness.settle(tester);
            expect(undone, 1);
          }
          dismissAllToast(showAnim: false);
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
