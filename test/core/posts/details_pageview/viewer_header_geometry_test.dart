import 'package:boorusama/core/posts/details_pageview/src/post_details_overlay.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final sortable in [false, true]) {
    testWidgets('header reclaims Info continuously, sortable=$sortable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        checkIfLargeScreen: () => false,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostDetailsOverlay(
              controller: controller,
              leftActions: const [],
              actions: const [],
              headerActions: [
                if (sortable)
                  const SizedBox(key: Key('sort'), width: 48, height: 48),
                const SizedBox(key: Key('view'), width: 48, height: 48),
              ],
              isLargeScreen: false,
              overlayCurvedAnimation: null,
            ),
          ),
        ),
      );
      final view = find.byKey(const Key('view'));
      final start = tester.getRect(view);
      if (sortable) {
        expect(
          start.left - tester.getRect(find.byKey(const Key('sort'))).right,
          4,
        );
      }
      for (final p in [0.25, 0.5, 0.75, 1.0, 0.6, 0.2, 0.0]) {
        controller.presentationProgress.value = p;
        await tester.pump();
        expect(tester.getRect(view).left, closeTo(start.left + 52 * p, .01));
        expect(tester.getRect(view).top, start.top);
        if (p >= .5) {
          expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsNothing);
          expect(
            find
                .byType(KurumiInfoCircleIcon)
                .evaluate()
                .where((e) => Focus.of(e).hasFocus),
            isEmpty,
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
