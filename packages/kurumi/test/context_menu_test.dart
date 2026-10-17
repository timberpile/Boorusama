// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:context_menus/context_menus.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  testWidgets('tapping outside a mobile context menu only dismisses the menu', (
    tester,
  ) async {
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
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('custom context menus render configured icons and badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KurumiCustomContextMenuOverlay(
          mobileLayout: false,
          child: Scaffold(
            body: ContextMenuRegion(
              contextMenu: GenericContextMenu(
                buttonConfigs: [
                  ContextMenuButtonConfig(
                    'Following',
                    onPressed: () {},
                    icon: const Badge(
                      label: Text('2'),
                      child: Icon(Icons.rss_feed),
                    ),
                  ),
                ],
              ),
              child: const Text('Target'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.text('Target'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
