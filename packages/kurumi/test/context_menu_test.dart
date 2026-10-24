// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:kurumi/kurumi.dart';

void main() {
  testWidgets('an open context menu owns local Back history until dismissed', (
    tester,
  ) async {
    late ModalRoute<dynamic> route;
    var canHandlePop = false;
    await tester.pumpWidget(
      MaterialApp(
        onNavigationNotification: (notification) {
          canHandlePop = notification.canHandlePop;
          return false;
        },
        home: Scaffold(
          body: Builder(
            builder: (context) {
              route = ModalRoute.of(context)!;
              return KurumiContextMenu(
                menuItemsBuilder: (_) => [
                  const KurumiContextMenuTile(title: 'Menu action'),
                ],
                child: const SizedBox(
                  width: 120,
                  height: 80,
                  child: Center(child: Text('Post')),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(route.willHandlePopInternally, isFalse);
    await tester.longPress(find.text('Post'));
    await tester.pumpAndSettle();
    expect(route.willHandlePopInternally, isTrue);
    expect(canHandlePop, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Menu action'), findsNothing);
    expect(route.willHandlePopInternally, isFalse);
    expect(canHandlePop, isFalse);
    expect(find.text('Post'), findsOneWidget);
    await tester.longPress(find.text('Post'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(route.willHandlePopInternally, isFalse);
    await tester.longPress(find.text('Post'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(route.willHandlePopInternally, isFalse);
  });

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

  for (final mode in ['ordinary', 'offstage', 'covered', 'clipped', 'nested']) {
    testWidgets('second right click resolves visible deepest target: $mode', (
      tester,
    ) async {
      Widget menu(String label, double width, double height, {Widget? child}) =>
          KurumiContextMenu(
            menuItemsBuilder: (_) => [
              KurumiContextMenuTile(title: '$label action', onTap: () {}),
            ],
            child: SizedBox(width: width, height: height, child: child),
          );
      final target = switch (mode) {
        'offstage' => Stack(
          children: [
            Offstage(child: menu('wrong', 40, 40)),
            menu('visible', 160, 80),
          ],
        ),
        'covered' => Stack(
          children: [
            menu('wrong', 40, 40),
            menu('visible', 160, 80),
          ],
        ),
        'clipped' => Stack(
          children: [
            menu('visible', 160, 80),
            SizedBox(
              width: 10,
              height: 10,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: 80,
                  maxHeight: 80,
                  child: menu('wrong', 80, 80),
                ),
              ),
            ),
          ],
        ),
        'nested' => menu(
          'wrong',
          160,
          80,
          child: Align(
            alignment: Alignment.topLeft,
            child: menu('visible', 80, 60),
          ),
        ),
        _ => menu('visible', 160, 80),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 24,
                  top: 24,
                  child: menu(
                    'initial',
                    120,
                    72,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
                Positioned(left: 350, top: 250, child: target),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(30, 30), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('initial action'), findsOneWidget);
      // Transparent children still provide the full intended gesture target.
      await tester.tapAt(
        const Offset(380, 280),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('initial action'), findsNothing);
      expect(find.text('wrong action'), findsNothing);
      expect(find.text('visible action'), findsOneWidget);
    });
  }

  testWidgets('context menu tiles render trailing icons and badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KurumiContextMenu(
            menuItemsBuilder: (_) => [
              KurumiContextMenuTile(
                title: 'Following',
                onTap: () {},
                trailing: const Badge(
                  label: Text('2'),
                  child: Icon(Icons.rss_feed),
                ),
              ),
            ],
            child: const Text('Target'),
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
