import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final keyboard in [false, true]) {
    testWidgets(
      'enlarged popup stays inside safe viewport with keyboard=$keyboard',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.padding = FakeViewPadding(
          top: 24,
          bottom: keyboard ? 0 : 24,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 300 : 0);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        String? action;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 20)),
            ),
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    top: keyboard ? 160 : 326,
                    right: 16,
                    child: KurumiPopupMenuButton(
                      semanticLabel: 'More',
                      items: [
                        for (final label in [
                          'Edit Alias',
                          'Remove Alias',
                          'Create Local Copy',
                          'Unsubscribe',
                        ])
                          KurumiPopupMenuItem(
                            title: Text(label),
                            icon: const Icon(Icons.edit_outlined),
                            onTap: () => action = label,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.byType(KurumiPopupMenuButton));
        await tester.pumpAndSettle();
        final first = tester.getRect(find.text('Edit Alias'));
        expect(first.top, greaterThanOrEqualTo(36));
        expect(first.right, lessThanOrEqualTo(308));
        await tester.tap(find.text('Edit Alias'));
        await tester.pumpAndSettle();
        expect(action, 'Edit Alias');
        action = null;
        await tester.tap(find.byType(KurumiPopupMenuButton));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Unsubscribe'));
        await tester.pumpAndSettle();
        final last = tester.getRect(find.text('Unsubscribe'));
        expect(last.bottom, lessThanOrEqualTo(keyboard ? 388 : 664));
        await tester.tap(find.text('Unsubscribe'));
        await tester.pumpAndSettle();
        expect(action, 'Unsubscribe');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('scrolling a long popup retains the page scroll position', (
    tester,
  ) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryScrollController(
            controller: page,
            child: ListView(
              children: [
                KurumiPopupMenuButton(
                  items: [
                    for (var i = 0; i < 40; i++)
                      KurumiPopupMenuItem(
                        title: Text('Item $i'),
                        onTap: () => selected = i == 39,
                      ),
                  ],
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(KurumiPopupMenuButton));
    await tester.pumpAndSettle();
    expect(page.positions, hasLength(1));
    await tester.ensureVisible(find.text('Item 39'));
    await tester.pumpAndSettle();
    expect(page.offset, 0);
    await tester.tap(find.text('Item 39'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
