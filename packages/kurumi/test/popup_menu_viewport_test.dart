import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final consumedInset in [false, true]) {
    for (final keyboardAfterOpen in [false, true]) {
      testWidgets(
        'short popup respects native keyboard with consumed=$consumedInset afterOpen=$keyboardAfterOpen',
        (tester) async {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(320, 640);
          addTearDown(tester.view.reset);
          if (!keyboardAfterOpen) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          }
          var selected = false;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  viewInsets: consumedInset ? EdgeInsets.zero : null,
                ),
                child: child!,
              ),
              home: Scaffold(
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    Positioned(
                      left: 136,
                      top: 400,
                      child: KurumiPopupMenuButton(
                        child: const SizedBox.square(
                          dimension: 48,
                          child: Icon(Icons.more_vert),
                        ),
                        items: [
                          KurumiPopupMenuItem(
                            title: const Text('One'),
                            onTap: () {},
                          ),
                          KurumiPopupMenuItem(
                            title: const Text('Two'),
                            onTap: () => selected = true,
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
          if (keyboardAfterOpen) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 180);
            await tester.pumpAndSettle();
          }
          final item = find.text('Two');
          final media = MediaQuery.of(tester.element(item));
          expect(media.viewInsets.bottom, consumedInset ? 0 : 180);
          expect(tester.getRect(item).top, greaterThanOrEqualTo(0));
          expect(tester.getRect(item).bottom, lessThanOrEqualTo(460));
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(selected, true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final keyboardHeight in [0.0, 180.0]) {
    testWidgets(
      'large popup remains scrollable above keyboard $keyboardHeight',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selected = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: keyboardHeight),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: KurumiPopupMenuButton(
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Icon(Icons.more_vert),
                  ),
                  items: [
                    for (var index = 0; index < 12; index++)
                      KurumiPopupMenuItem(
                        title: Text('Action $index'),
                        onTap: () => selected = true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(KurumiPopupMenuButton));
        await tester.pumpAndSettle();
        final scroll = find.byType(SingleChildScrollView);
        final bounds = tester.getRect(scroll);
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(640 - keyboardHeight));
        await tester.scrollUntilVisible(
          find.text('Action 11'),
          120,
          scrollable: find.descendant(
            of: scroll,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Action 11'));
        await tester.pumpAndSettle();
        expect(selected, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
