import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_header_sliver.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kurumi/kurumi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final pinned in [false, true]) {
    testWidgets('toolbar scroll visibility with pinning $pinned', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              // ignore: deprecated_member_use
              MaterialUiCompatibilityBridge(
                child: KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
              ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                TimelineHeaderSliver(
                  keepVisible: pinned,
                  child: const SizedBox(height: 56, child: Text('Toolbar')),
                ),
                SliverList.builder(
                  itemCount: 80,
                  itemBuilder: (_, index) => SizedBox(
                    height: 100,
                    child: Text('Post $index'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        find.text('Toolbar').hitTestable(),
        pinned ? findsOneWidget : findsNothing,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 32));
      await tester.pumpAndSettle();
      expect(find.text('Toolbar').hitTestable(), findsOneWidget);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(200),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('floating toolbar survives empty-to-content error recovery', (
    tester,
  ) async {
    final show = ValueNotifier(false);
    addTearDown(show.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: show,
          builder: (context, visible, _) => CustomScrollView(
            slivers: [
              TimelineHeaderSliver(
                child: visible
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Recovered toolbar'),
                      )
                    : const SizedBox.shrink(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1200)),
            ],
          ),
        ),
      ),
    );
    show.value = true;
    await tester.pump();
    expect(find.text('Recovered toolbar').hitTestable(), findsOneWidget);
    show.value = false;
    await tester.pump();
    show.value = true;
    await tester.pump();
    expect(find.text('Recovered toolbar').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'toolbar renders the backdrop through its transparent surface in $brightness',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: RepaintBoundary(
              key: key,
              child: const Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Color(0xff13579b))),
                  CustomScrollView(
                    slivers: [
                      TimelineHeaderSliver(child: SizedBox(height: 60)),
                      SliverToBoxAdapter(child: SizedBox(height: 1200)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final pixel = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset = (20 * image.width + 20) * 4;
            return List.generate(4, (i) => bytes.getUint8(offset + i));
          } finally {
            image.dispose();
          }
        });
        expect(pixel, [0x13, 0x57, 0x9b, 0xff]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
