import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final width in [320.0, 363.4, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('fixed segments fit $width pixels at $scale text scale', (
        tester,
      ) async {
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: Center(
                      child: KurumiSegmentedButton<int>(
                        initialValue: 0,
                        fixedWidth: 120,
                        segments: const {
                          0: 'Ordered',
                          1: 'Latest',
                          2: 'Oldest',
                        },
                        onChanged: (value) => selected = value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final control = tester.getRect(
          find.byType(KurumiSlidingSegmentedControl<int>),
        );
        expect(control.width, lessThanOrEqualTo(width + 0.01));
        await tester.tap(find.text('Oldest'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
        final thumb = tester.getRect(
          find.byType(KurumiSegmentAnimationPanel<int>),
        );
        expect(thumb.left, greaterThanOrEqualTo(control.left));
        expect(thumb.right, lessThanOrEqualTo(control.right + 0.01));
      });
    }
  }
}
