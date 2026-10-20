import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/tags/show/src/pages/show_tag_list_page_scaffold.dart';
import 'package:boorusama/core/tags/show/src/widgets/show_tag_list.dart';
import 'package:boorusama/core/widgets/widgets.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'filtered tag selection copies the visible tag rather than its old source index',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(tester);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await harness.pumpUntilFound(tester, postTile(101));
      final strings = appStrings(tester);
      await driver.openPostMenu(101, via: PostMenuOpener.rightClick);
      await driver.choosePostMenuAction(strings.post.action.view_tags);
      await harness.pumpUntilFound(
        tester,
        find.byType(ShowTagListPageScaffold),
      );
      await harness.settle(tester);
      final selection = SelectionMode.of(
        tester.element(find.byType(ShowTagList)),
      );
      Future<void> enterSelection() async {
        await tester.tap(
          find.descendant(
            of: find.byType(KurumiAppBar),
            matching: find.byType(KurumiPopupMenuButton),
          ),
        );
        await harness.settle(tester);
        await tester.tap(
          find.widgetWithText(
            KurumiPopupMenuItem,
            strings.generic.action.select,
          ),
        );
        await harness.settle(tester);
      }

      await enterSelection();
      selection.selectAll([0, 1]);
      await tester.enterText(
        find.descendant(
          of: find.byType(ShowTagListPageScaffold),
          matching: find.byType(EditableText),
        ),
        'blue',
      );
      await harness.settle(tester);
      expect(selection.isActive, isFalse);
      expect(selection.selection, isEmpty);
      await enterSelection();
      await tester.tap(find.text('blue hair'));
      await harness.settle(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(
        find.widgetWithText(MultiSelectButton, strings.tags.actions.copy),
      );
      await harness.pumpUntil(tester, () => copied != null);
      expect(copied, 'blue_hair');
      dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
