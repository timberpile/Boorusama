import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final custom in [false, true]) {
    testWidgets(
      'provided popup focus opens and restores its trigger (custom=$custom)',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: KurumiPopupMenuButton(
                  focusNode: focus,
                  items: [
                    KurumiPopupMenuItem(
                      title: const Text('Action'),
                      onTap: () {},
                    ),
                  ],
                  child: custom ? const Text('Open') : null,
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        expect(focus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsNothing);
        expect(focus.hasPrimaryFocus, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
