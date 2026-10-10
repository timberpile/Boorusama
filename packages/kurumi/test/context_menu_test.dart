// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:kurumi/kurumi.dart';

void main() {
  testWidgets('tapping outside a mobile context menu only dismisses the menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    var firstPostTaps = 0;
    var otherPostTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 24,
                top: 24,
                child: KurumiContextMenu(
                  menuItemsBuilder: (_) => [
                    const KurumiContextMenuTile(title: 'Menu action'),
                  ],
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => firstPostTaps++,
                    child: const SizedBox(
                      width: 120,
                      height: 72,
                      child: Center(child: Text('First post')),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 350,
                top: 200,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => otherPostTaps++,
                  child: const SizedBox(
                    width: 180,
                    height: 80,
                    child: Center(child: Text('Other post')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.longPress(find.text('First post'));
    await tester.pumpAndSettle();
    expect(find.text('Menu action'), findsOneWidget);

    final otherPostPosition = tester.getCenter(find.text('Other post'));
    await tester.tapAt(otherPostPosition);
    await tester.pumpAndSettle();
    expect(find.text('Menu action'), findsNothing);
    expect(firstPostTaps, 0);
    expect(otherPostTaps, 0);

    await tester.tapAt(otherPostPosition);
    await tester.pump();
    expect(otherPostTaps, 1);
  });
}
