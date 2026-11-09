import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
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
