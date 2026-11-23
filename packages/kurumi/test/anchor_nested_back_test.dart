import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('an anchor delegates Back to its nested owner before dismissal', (
    tester,
  ) async {
    final controller = AnchorController();
    addTearDown(controller.dispose);
    var depth = 2;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KurumiAnchor(
            controller: controller,
            onBack: () {
              calls++;
              if (depth > 0) {
                depth--;
              } else {
                controller.hide();
              }
            },
            overlayBuilder: (_) =>
                TextButton(onPressed: () {}, child: const Text('Nested popup')),
            child: TextButton(
              onPressed: controller.show,
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(depth, 1);
    expect(find.text('Nested popup'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(depth, 0);
    expect(find.text('Nested popup'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(find.text('Nested popup'), findsNothing);
  });
}
