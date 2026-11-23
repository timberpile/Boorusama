import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final material3 in [false, true]) {
    testWidgets(
      'compact circular surface retains its padded touch target, M3=$material3',
      (
        tester,
      ) async {
        var pressed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: material3),
            home: Scaffold(
              body: Center(
                child: KurumiCircularIconButton(
                  visualSize: 40,
                  semanticLabel: 'Details',
                  onPressed: () => pressed++,
                  icon: const KurumiInfoCircleIcon(),
                ),
              ),
            ),
          ),
        );
        final button = find.byType(KurumiCircularIconButton);
        final surface = find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.shape is CircleBorder,
          ),
        );
        expect(tester.getSize(surface), const Size(40, 40));
        expect(tester.getSize(button), const Size(48, 48));
        await tester.tapAt(tester.getTopLeft(button) + const Offset(1, 1));
        expect(pressed, 1);
        await tester.tapAt(tester.getBottomRight(button) - const Offset(1, 1));
        expect(pressed, 2);
      },
    );
  }
}
