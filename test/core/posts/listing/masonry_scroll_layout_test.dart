import 'dart:math' as math;

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_masonry_grid/sliver_masonry_grid.dart';

void main() {
  for (final columns in [1, 2, 3]) {
    testWidgets('Masonry relayout during scrolling with $columns columns', (
      tester,
    ) async {
      final scroll = ScrollController();
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
      }
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
      for (final ratio in ratios) {
        ratio.dispose();
      }
    });
  }
}
