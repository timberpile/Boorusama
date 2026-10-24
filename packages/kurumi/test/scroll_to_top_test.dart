import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('content-only shrink hides a button that does not rebuild', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 500);
    final count = ValueNotifier(100);
    addTearDown(controller.dispose);
    addTearDown(count.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ValueListenableBuilder<int>(
                valueListenable: count,
                builder: (_, value, _) => ListView.builder(
                  controller: controller,
                  itemCount: value,
                  itemExtent: 100,
                  itemBuilder: (_, index) => Text('$index'),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: KurumiScrollToTop(
                  scrollController: controller,
                  layoutChanges: count,
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _showButton(tester);
    count.value = 1;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));
    expect(_opacity(tester), 0);
  });

  testWidgets('hides at the top during one continuous upward drag', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 500);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);

    final gesture = await tester.startGesture(const Offset(100, 150));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await tester.pump(kThemeAnimationDuration);
    expect(controller.offset, greaterThan(0));
    expect(_opacity(tester), 1);

    await gesture.moveBy(const Offset(0, 800));
    await tester.pump();
    await tester.pump(kThemeAnimationDuration);
    expect(controller.offset, closeTo(0, 0.5));
    expect(_opacity(tester), 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final offset in [0.0, 0.25]) {
    testWidgets('hides after jumping to the top boundary at $offset', (
      tester,
    ) async {
      final controller = ScrollController(initialScrollOffset: 500);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await _showButton(tester);
      controller.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(_opacity(tester), 0);
    });
  }

  testWidgets('hides after programmatic and ballistic scrolling to the top', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 500);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await _showButton(tester);
    final animation = controller.animateTo(
      0,
      duration: kThemeAnimationDuration,
      curve: Curves.linear,
    );
    await tester.pumpAndSettle();
    await animation;
    expect(_opacity(tester), 0);

    controller.jumpTo(500);
    await tester.fling(find.byType(ListView), const Offset(0, 1000), 2000);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));
    expect(_opacity(tester), 0);
  });

  testWidgets('resets visibility and listens to a replacement controller', (
    tester,
  ) async {
    final first = ScrollController(initialScrollOffset: 500);
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(_app(first));
    await _showButton(tester);
    await tester.pumpWidget(_app(second));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
    second.jumpTo(500);
    await _showButton(tester);
    second.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides when shrinking content removes the scroll range', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 500);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await _showButton(tester);
    await tester.pumpWidget(_app(controller, itemCount: 1));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));
    expect(_opacity(tester), 0);
  });

  testWidgets('is safe before a controller is attached', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: KurumiScrollToTop(
          scrollController: controller,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _showButton(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 120));
  await tester.pumpAndSettle();
  expect(_opacity(tester), 1);
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(KurumiScrollToTop),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

Widget _app(ScrollController controller, {int itemCount = 100}) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        ListView.builder(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          itemCount: itemCount,
          itemExtent: 100,
          itemBuilder: (_, index) => Text('$index'),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: KurumiScrollToTop(
            scrollController: controller,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ],
    ),
  ),
);
