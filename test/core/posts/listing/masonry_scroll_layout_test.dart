import 'dart:math' as math;

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_masonry_grid/sliver_masonry_grid.dart';

void main() {
  testWidgets('Masonry column reconstruction can correct the viewport offset', (
    tester,
  ) async {
    final scroll = _CorrectionRecordingController();
    final columns = ValueNotifier(2);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 360,
            height: 600,
            child: CustomScrollView(
              controller: scroll,
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              slivers: [
                ValueListenableBuilder(
                  valueListenable: columns,
                  builder: (context, count, _) => SliverMasonryGrid.count(
                    crossAxisCount: count,
                    mainAxisSpacing: 4,
                    childCount: 100,
                    itemBuilder: (context, index) =>
                        const SizedBox(height: 160),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    scroll.jumpTo(900);
    await tester.pump();
    scroll.corrections.clear();
    final before = scroll.offset;
    columns.value = 3;
    await tester.pump();
    expect(scroll.corrections, isNotEmpty);
    expect(
      scroll.offset,
      closeTo(
        before +
            scroll.corrections.fold<double>(0, (sum, delta) => sum + delta),
        0.01,
      ),
    );
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('BOORUSAMA_DEBUG_MASONRY_RESIZE')) {
      debugPrint(
        'masonry-diagnostic column-change before=$before '
        'after=${scroll.offset} corrections=${scroll.corrections}',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    scroll.dispose();
    columns.dispose();
  });

  for (final columns in [1, 2, 3]) {
    testWidgets('Masonry relayout during scrolling with $columns columns', (
      tester,
    ) async {
      final scroll = _CorrectionRecordingController();
      final ratios = List.generate(100, (_) => ValueNotifier<double>(1));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 360,
              height: 600,
              child: CustomScrollView(
                controller: scroll,
                scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                slivers: [
                  SliverMasonryGrid.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childCount: ratios.length,
                    itemBuilder: (context, index) => ValueListenableBuilder(
                      key: ValueKey(index),
                      valueListenable: ratios[index],
                      builder: (context, ratio, _) => AspectRatio(
                        aspectRatio: ratio,
                        child: LayoutBuilder(
                          builder: (context, constraints) => const ColoredBox(
                            color: Color(0xff334455),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final random = math.Random(163);
      for (var frame = 0; frame < 120; frame++) {
        final offset = frame < 60 ? frame * 65.0 : (119 - frame) * 65.0;
        scroll.jumpTo(math.min(offset, scroll.position.maxScrollExtent));
        for (var index = frame % 3; index < ratios.length; index += 3) {
          ratios[index].value = [0.5, 1.0, 1.5, 2.0][random.nextInt(4)];
        }
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scroll frame $frame');
        if (const bool.fromEnvironment('BOORUSAMA_DEBUG_MASONRY_RESIZE')) {
          final grid = tester.renderObject<RenderSliverMasonryGrid>(
            find.byType(SliverMasonryGrid),
          );
          final child = grid.firstChild!;
          final data = child.parentData! as SliverMasonryGridParentData;
          debugPrint(
            'masonry-diagnostic columns=$columns frame=$frame '
            'requested=$offset pixels=${scroll.offset} '
            'firstIndex=${grid.indexOf(child)} height=${child.size.height} '
            'layoutOffset=${data.layoutOffset} '
            'cachedHeight=${data.lastMainAxisExtent} '
            'corrections=${scroll.corrections}',
          );
        }
        scroll.corrections.clear();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      for (final ratio in ratios) {
        ratio.dispose();
      }
    });
  }
}

class _CorrectionRecordingController extends ScrollController {
  final corrections = <double>[];

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _CorrectionRecordingPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    corrections: corrections,
  );
}

class _CorrectionRecordingPosition extends ScrollPositionWithSingleContext {
  _CorrectionRecordingPosition({
    required super.physics,
    required super.context,
    required this.corrections,
    super.oldPosition,
  });

  final List<double> corrections;

  @override
  void correctBy(double correction) {
    corrections.add(correction);
    super.correctBy(correction);
  }
}
