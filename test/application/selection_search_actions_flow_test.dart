import 'package:boorusama/core/widgets/booru_menu_button_row.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:selection_mode/selection_mode.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

Finder searchAction() => find.byWidgetPredicate(
  (widget) =>
      widget is MultiSelectPopupButton && widget.name == 'Modify Search',
);

void main() {
  for (final (label, boundary) in [
    ('This Post and Newer', '>=101'),
    ('This Post and Older', '<=101'),
  ]) {
    testWidgets(
      'selection-only $label refines the current search inclusively',
      (tester) async {
        final compact = boundary.startsWith('<=');
        if (compact) {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final backend = FakeBooruBackend();
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          phone: compact ? TestPhone.smallPortrait : TestPhone.portrait,
        );
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await harness.pumpUntilFound(tester, postTile(101));
        await driver.openSearch();
        await driver.submitSearch('cat');
        await harness.pumpUntilFound(tester, postTile(101));
        expect(searchAction(), findsNothing);
        if (compact) {
          await tester.longPress(postTile(101));
          await harness.settle(tester);
        } else {
          await driver.openPostMenu(101, via: PostMenuOpener.rightClick);
          expect(
            find.descendant(
              of: find.byType(KurumiContextMenuTile),
              matching: find.text('Modify Search'),
            ),
            findsNothing,
          );
          await driver.choosePostMenuAction(
            appStrings(tester).generic.action.select,
          );
        }
        expect(searchAction(), findsOneWidget);
        final selection = SelectionMode.of(tester.element(postTile(101)));
        if (compact) {
          final field = find.descendant(
            of: find.byType(SearchAppBar),
            matching: find.byType(EditableText),
          );
          await tester.showKeyboard(field);
          await harness.settle(tester);
          expect(harness.keyboard.isShown, isTrue);
        }
        await tester.tap(searchAction());
        await harness.settle(tester);
        final choices = find.byType(KurumiPopupMenuItem);
        expect(
          find.descendant(of: choices, matching: find.text('Modify Search')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: choices,
            matching: find.text('This Post and Newer'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: choices,
            matching: find.text('This Post and Older'),
          ),
          findsOneWidget,
        );
        final choice = find.descendant(of: choices, matching: find.text(label));
        if (compact) {
          final bounds = tester.getRect(choice);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(
            bounds.right,
            lessThanOrEqualTo(TestPhone.smallPortrait.size.width),
          );
          expect(
            bounds.bottom,
            lessThanOrEqualTo(harness.keyboard.visibleArea.bottom),
          );
        }
        await tester.tap(choice);
        await harness.pumpUntil(
          tester,
          () => backend.requests.whereType<FakeBooruPostRequest>().any(
            (request) => request.query == 'cat id:$boundary',
          ),
        );
        await harness.settle(tester);
        expect(find.byType(SearchPageScaffold), findsOneWidget);
        expect(selection.isActive, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('search actions require exactly one selected post', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    backend.posts[1] = TestPost(id: 102, tags: const {'cat'});
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
    );
    final driver = AppFlowDriver(tester: tester, harness: harness);
    await harness.pumpUntilFound(tester, postTile(101));
    await driver.openSearch();
    await driver.submitSearch('cat');
    await harness.pumpUntilFound(tester, postTile(101));
    await tester.longPress(postTile(101));
    await harness.settle(tester);
    expect(searchAction(), findsOneWidget);
    await tester.tap(postTile(102));
    await harness.settle(tester);
    expect(searchAction(), findsNothing);
    await tester.tap(postTile(102));
    await harness.settle(tester);
    expect(searchAction(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Post Viewer opened from search has no search action', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(tester);
    final driver = AppFlowDriver(tester: tester, harness: harness);
    await harness.pumpUntilFound(tester, postTile(101));
    await driver.openSearch();
    await driver.submitSearch('cat');
    await driver.openPost(101);
    await harness.settle(tester);
    final rows = tester.widgetList<BooruMenuButtonRow>(
      find.byType(BooruMenuButtonRow),
    );
    expect(rows, isNotEmpty);
    expect(
      rows.expand((row) => row.buttons).map((button) => button.title),
      isNot(contains('Modify Search')),
    );
    expect(searchAction(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary Browse selection does not expose a search action', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(tester);
    await harness.pumpUntilFound(tester, postTile(101));
    await tester.longPress(postTile(101));
    await harness.settle(tester);
    expect(searchAction(), findsNothing);
    expect(SelectionMode.of(tester.element(postTile(101))).isActive, isTrue);
    expect(tester.takeException(), isNull);
  });
}
