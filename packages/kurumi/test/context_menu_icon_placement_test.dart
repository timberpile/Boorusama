import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('action leads and count trails: $direction at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 568),
                  textScaler: TextScaler.linear(scale),
                  viewInsets: EdgeInsets.only(bottom: scale == 2 ? 180 : 0),
                ),
                child: Scaffold(
                  body: Center(
                    child: KurumiContextMenu(
                      menuItemsBuilder: (_) => [
                        KurumiContextMenuTile(
                          title: 'Copy tag',
                          leading: const Icon(
                            Icons.copy,
                            key: ValueKey('action-icon'),
                          ),
                          trailing: const Text(
                            '3',
                            key: ValueKey('status-count'),
                          ),
                          onTap: () => calls++,
                        ),
                      ],
                      child: const Text('Open menu'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.longPress(find.text('Open menu'));
        await tester.pumpAndSettle();
        final icon = tester.getRect(find.byKey(const ValueKey('action-icon')));
        final label = tester.getRect(find.text('Copy tag'));
        final count = tester.getRect(
          find.byKey(const ValueKey('status-count')),
        );
        if (direction == TextDirection.ltr) {
          expect(icon.right, lessThan(label.left));
          expect(count.left, greaterThan(label.right));
        } else {
          expect(icon.left, greaterThan(label.right));
          expect(count.right, lessThan(label.left));
        }
        expect(
          tester.getRect(find.text('Copy tag')).bottom,
          lessThanOrEqualTo(568 - (scale == 2 ? 180 : 0)),
        );
        await tester.tapAt(icon.center);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('Copy tag'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
