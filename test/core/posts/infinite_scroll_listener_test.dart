import 'package:boorusama/core/posts/listing/src/widgets/infinite_scroll_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    (description: 'the first page', itemCount: 20),
    (description: 'several accumulated pages', itemCount: 60),
  ];

  for (final c in cases) {
    testWidgets(
      'starts prefetching one viewport before the end for ${c.description}',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        var fetchCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: InfiniteScrollListener(
              scrollController: scrollController,
              onBottomReached: () => fetchCount++,
              child: ListView.builder(
                controller: scrollController,
                itemCount: c.itemCount,
                itemExtent: 100,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey(index),
                  height: 100,
                ),
              ),
            ),
          ),
        );

        final position = scrollController.position;
        final prefetchOffset =
            position.maxScrollExtent - position.viewportDimension;

        scrollController.jumpTo(prefetchOffset - 1);
        expect(fetchCount, 0);

        scrollController.jumpTo(prefetchOffset);
        expect(fetchCount, 1);
      },
    );
  }
}
