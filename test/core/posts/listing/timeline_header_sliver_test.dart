import 'package:flutter/rendering.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_header_sliver.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kurumi/kurumi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (initialOffset, pinned) in [
    (250.0, false),
    (280.0, false),
    (600.0, false),
    (250.0, true),
  ]) {
    testWidgets(
      'a floating toolbar moves once per drag at $initialOffset with action bar pinned=$pinned',
      (
        tester,
      ) async {
        const controls = ValueKey('floating-controls');
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    pinned: pinned,
                    title: const Text('Actions'),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  const TimelineHeaderSliver(
                    child: SizedBox(
                      key: controls,
                      height: 56,
                      child: Text('Toolbar'),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: 80,
                    itemBuilder: (_, index) =>
                        SizedBox(height: 100, child: Text('Post $index')),
                  ),
                ],
              ),
            ),
          ),
        );
        controller.jumpTo(initialOffset);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 45));
        await tester.pumpAndSettle();
        final toolbar = find.byKey(controls);
        expect(toolbar.hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(toolbar).dy,
          tester.getBottomLeft(find.byType(NavigationToolbar)).dy,
        );

        final gesture = await tester.startGesture(const Offset(150, 400));
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        final before = tester.getTopLeft(toolbar).dy;
        await gesture.moveBy(const Offset(0, -24));
        await tester.pump();
        expect(tester.getTopLeft(toolbar).dy - before, closeTo(-24, .01));
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump();
        expect(tester.getTopLeft(toolbar).dy - before, closeTo(-12, .01));
        await gesture.up();
        await tester.pumpAndSettle();
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(toolbar).dy, 176);
      },
    );
  }

  for (final insetAlreadyConsumed in [false, true]) {
    testWidgets(
      'pinned controls respect status inset without double padding: consumed=$insetAlreadyConsumed',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        const controls = ValueKey('safe-pinned-controls');
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24),
                viewPadding: const EdgeInsets.only(top: 24),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                top: insetAlreadyConsumed,
                bottom: false,
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    const SliverAppBar(
                      floating: true,
                      snap: true,
                      title: Text('Actions'),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    const TimelineHeaderSliver(
                      keepVisible: true,
                      child: SizedBox(
                        key: controls,
                        height: 56,
                        child: Text('Pinned controls'),
                      ),
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
          ),
        );
        expect(tester.getTopLeft(find.byKey(controls)).dy, 200);
        controller.jumpTo(186);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(controls)).dy, 24);
        controller.jumpTo(600);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(controls)).dy, 24);
        expect(find.byKey(controls).hitTestable(), findsOneWidget);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, 80));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(controls)).dy,
          tester.getBottomLeft(find.byType(NavigationToolbar)).dy,
        );
        expect(controller.offset, greaterThan(200));
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets(
    'oversized pinned controls scroll fully into view and repin when they fit',
    (tester) async {
      final controller = ScrollController();
      final headerExtent = ValueNotifier<double>(400);
      addTearDown(controller.dispose);
      addTearDown(headerExtent.dispose);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 320);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Widget controls() => ValueListenableBuilder<double>(
        valueListenable: headerExtent,
        builder: (context, extent, _) => SizedBox(
          height: extent,
          child: Column(
            children: [
              const TextField(
                key: ValueKey('timeline-search'),
                decoration: InputDecoration(labelText: 'Search posts'),
              ),
              const Expanded(child: SizedBox.expand()),
              SizedBox(
                height: 56,
                child: Center(
                  child: FilledButton(
                    key: const ValueKey('timeline-bottom-action'),
                    onPressed: () {},
                    child: const Text('Bottom action'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                TimelineHeaderSliver(
                  keepVisible: true,
                  child: controls(),
                ),
                SliverList.builder(
                  itemCount: 40,
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
      expect(
        MediaQuery.sizeOf(tester.element(find.byType(CustomScrollView))),
        const Size(640, 320),
      );
      expect(find.byKey(const ValueKey('timeline-search')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timeline-bottom-action')).hitTestable(),
        findsNothing,
      );

      // The oversized header must leave its natural scroll extent available.
      controller.jumpTo(120);
      await tester.pumpAndSettle();
      final bottomAction = tester.getRect(
        find.byKey(const ValueKey('timeline-bottom-action')),
      );
      expect(bottomAction.top, greaterThanOrEqualTo(0));
      expect(bottomAction.bottom, lessThanOrEqualTo(320));
      expect(
        find.byKey(const ValueKey('timeline-bottom-action')).hitTestable(),
        findsOneWidget,
      );
      expect(controller.offset, 120);

      // A rotation and content reflow bring the full header below the usable
      // viewport extent. It should regain pinned behavior without replacing
      // the controls or leaving the previous natural-scroll translation.
      headerExtent.value = 220;
      tester.view.physicalSize = const Size(640, 800);
      await tester.pumpAndSettle();
      expect(
        MediaQuery.sizeOf(tester.element(find.byType(CustomScrollView))),
        const Size(640, 800),
      );
      controller.jumpTo(600);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('timeline-search'))).dy,
        0,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('timeline-bottom-action')))
            .bottom,
        lessThanOrEqualTo(220),
      );
      expect(
        find.byKey(const ValueKey('timeline-bottom-action')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('timeline-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
      'toolbar shades its entire bounds with the shared overflow surface in $brightness',
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
          final image = await boundary.toImage();
          try {
            final bytes = (await image.toByteData())!;
            final offset = (20 * image.width + 20) * 4;
            return List.generate(4, (i) => bytes.getUint8(offset + i));
          } finally {
            image.dispose();
          }
        });
        expect(pixel, [0x0a, 0x2c, 0x4e, 0xff]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
