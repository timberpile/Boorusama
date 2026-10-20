import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final inherited in [true, false]) {
    testWidgets(
      'touch policy preserves secondary and keyboard triggers (inherited=$inherited)',
      (tester) async {
        final focus = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KurumiContextMenuPolicy(
                touchLongPress: false,
                child: KurumiContextMenu(
                  touchLongPress: inherited ? null : false,
                  menuItemsBuilder: (_) => [
                    const KurumiContextMenuTile(title: 'Action'),
                  ],
                  child: Focus(
                    focusNode: focus,
                    child: const SizedBox(
                      width: 200,
                      height: 100,
                      child: Text('Item'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.longPress(find.text('Item'));
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsNothing);
        await tester.tap(
          find.text('Item'),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.f10);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        focus.dispose();
      },
    );
  }
}
