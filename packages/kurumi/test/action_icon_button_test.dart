import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  for (final material3 in [false, true]) {
    for (final direction in TextDirection.values) {
      for (final size in [20.0, 24.0]) {
        testWidgets(
          'dropdown fits 48 dp, M3=$material3, $direction, size=$size',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => Material(child: child),
                theme: ThemeData(useMaterial3: material3),
                home: Directionality(
                  textDirection: direction,
                  child: Center(
                    child: UnconstrainedBox(
                      child: KurumiActionIconButton(
                        tooltip: 'Save',
                        showDropdown: true,
                        iconSize: size,
                        onPressed: () {},
                        onLongPress: () {},
                        icon: const Icon(Icons.bookmark),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final button = tester.getRect(find.byType(IconButton));
            final iconFinder = find.byIcon(Icons.bookmark);
            final icon = tester.getRect(iconFinder);
            final chevron = tester.getRect(find.byIcon(Icons.expand_more));
            expect(button.size, const Size(48, 48));
            expect(icon.size, Size.square(size));
            expect(IconTheme.of(tester.element(iconFinder)).size, size);
            expect(chevron.size, const Size(16, 16));
            expect(button.contains(icon.topLeft), isTrue);
            expect(button.inflate(.001).contains(icon.bottomRight), isTrue);
            expect(button.contains(chevron.topLeft), isTrue);
            expect(button.inflate(.001).contains(chevron.bottomRight), isTrue);
            expect(icon.center.dy, chevron.center.dy);
            expect(
              direction == TextDirection.ltr
                  ? chevron.left >= icon.right
                  : chevron.right <= icon.left,
              isTrue,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('tap and hold stay separate; a hold does not select the icon', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Material(child: child),
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
        builder: (context, child) => Material(child: child),
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
        builder: (context, child) => Material(child: child),
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
    expect(
      tester.getSize(find.byIcon(Icons.bookmark_border)),
      const Size.square(24),
    );
  });
}
