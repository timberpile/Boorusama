import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  testWidgets('adaptive overflow keeps action icons and accessible labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var invoked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: KurumiAdaptiveButtonRow.menu(
                  overflowLabel: 'More',
                  buttonWidth: 72,
                  maxVisibleButtons: 2,
                  buttons: [
                    KurumiButtonData(
                      widget: IconButton(
                        icon: const Icon(Icons.bookmark_border),
                        onPressed: () {},
                      ),
                      title: 'Bookmark',
                      required: true,
                    ),
                    KurumiButtonData(
                      widget: const SizedBox.shrink(),
                      title: 'View in Browser',
                      icon: const Icon(Icons.open_in_browser),
                      placement: KurumiButtonPlacement.menuOnly,
                      onTap: () => invoked = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      final action = find.text('View in Browser');
      final row = find.ancestor(of: action, matching: find.byType(Row)).first;
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.open_in_browser)),
        findsOneWidget,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(invoked, isTrue);
      expect(find.text('View in Browser'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('long icon menus scroll within a short viewport', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 140);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    try {
      var invoked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Center(
              child: SizedBox(
                width: 280,
                child: KurumiAdaptiveButtonRow.menu(
                  overflowLabel: 'More',
                  buttonWidth: 72,
                  maxVisibleButtons: 2,
                  buttons: [
                    KurumiButtonData(
                      widget: IconButton(
                        icon: const Icon(Icons.bookmark),
                        onPressed: () {},
                      ),
                      title: 'Bookmark',
                      required: true,
                    ),
                    for (var i = 0; i < 12; i++)
                      KurumiButtonData(
                        widget: const SizedBox.shrink(),
                        title: 'Long action $i',
                        icon: const Icon(Icons.open_in_browser),
                        placement: KurumiButtonPlacement.menuOnly,
                        onTap: () => invoked = true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final last = find.text('Long action 11');
      final scroller = find.byType(Scrollable).last;
      final position = tester.state<ScrollableState>(scroller).position;
      expect(position.maxScrollExtent, greaterThan(0));

      for (var i = 0; i < 32 && position.extentAfter > 0; i++) {
        await tester.drag(scroller, const Offset(0, -140));
        await tester.pumpAndSettle();
      }
      expect(
        position.extentAfter,
        0,
        reason: 'viewport: ${tester.getRect(scroller)}',
      );
      final viewport = tester.getRect(scroller);
      expect(viewport.top, greaterThanOrEqualTo(36));
      expect(viewport.bottom, lessThanOrEqualTo(268));
      expect(last.hitTestable(), findsOneWidget);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(invoked, isTrue);
      expect(last, findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
