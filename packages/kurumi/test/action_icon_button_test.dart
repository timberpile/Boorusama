import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('dropdown is trailing and contained, $direction', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: KurumiActionIconButton(
                tooltip: 'Save',
                showDropdown: true,
                onPressed: () {},
                onLongPress: () {},
                icon: const Icon(Icons.bookmark),
              ),
            ),
          ),
        ),
      );
      final button = tester.getRect(find.byType(IconButton));
      final icon = tester.getRect(find.byIcon(Icons.bookmark));
      final chevron = tester.getRect(find.byIcon(Icons.expand_more));
      expect(button.width, greaterThanOrEqualTo(48));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(button.contains(chevron.topLeft), isTrue);
      expect(button.contains(chevron.bottomRight), isTrue);
      expect(icon.center.dy, chevron.center.dy);
      expect(
        direction == TextDirection.ltr
            ? chevron.left >= icon.right
            : chevron.right <= icon.left,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tap and hold stay separate; a hold does not select the icon', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: KurumiActionIconButton(
            tooltip: 'Save',
            showDropdown: true,
            onPressed: () => taps++,
            onLongPress: () => holds++,
            icon: const Icon(Icons.bookmark_border),
          ),
        ),
      ),
    );
    await tester.longPress(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(holds, 1);
    expect(taps, 0);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    expect(taps, 1);
  });

  testWidgets('disabled action also disables its hold action', (tester) async {
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: KurumiActionIconButton(
            tooltip: 'Save',
            showDropdown: true,
            onPressed: null,
            onLongPress: () => holds++,
            icon: const Icon(Icons.bookmark_border),
          ),
        ),
      ),
    );
    await tester.longPress(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(holds, 0);
  });

  testWidgets('ordinary action has no dropdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: KurumiActionIconButton(
            tooltip: 'Save',
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });
}
