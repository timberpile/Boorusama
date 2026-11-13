import 'package:boorusama/core/posts/details/src/widgets/media_group_page_indicator.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_page_view_scope.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets('hidden system bars reserve no top inset for the reading hint', (
    tester,
  ) async {
    final viewer = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      initialHideOverlay: true,
      checkIfLargeScreen: () => false,
    );
    try {
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: const EdgeInsets.only(top: 24)),
              child: child!,
            ),
            home: PostDetailsPageViewScope(
              controller: viewer,
              child: const MediaGroupPageIndicator(
                memberKey: 'page:0',
                page: 1,
                total: 3,
              ),
            ),
          ),
        ),
      );
      final hint = find.byType(AnimatedOpacity);
      expect(tester.getTopLeft(hint).dy, 4);
      viewer.showAllUI();
      await tester.pump();
      expect(tester.getTopLeft(hint).dy, greaterThanOrEqualTo(24 + 52));
      await viewer.expandToSnapPoint();
      await tester.pump();
      expect(
        tester.getTopLeft(hint).dy,
        24,
        reason: 'Details places the hint directly below the system bar',
      );
      await viewer.resetSheet();
      viewer.hideAllUI();
      await tester.pump();
      expect(tester.getTopLeft(hint).dy, 4);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      viewer.dispose();
    }
  });

  testWidgets(
    'reading hint expires after the last Page change without changing UI state',
    (tester) async {
      final viewer = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        initialHideOverlay: true,
        checkIfLargeScreen: () => false,
      );
      addTearDown(viewer.dispose);
      var taps = 0;
      Future<void> show(int page) => tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            home: PostDetailsPageViewScope(
              controller: viewer,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: MediaGroupPageIndicator(
                  memberKey: 'page:$page',
                  page: page,
                  total: 5,
                ),
              ),
            ),
          ),
        ),
      );
      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      await show(1);
      expect(opacity(), 1);
      expect(viewer.overlay.value, isFalse);
      await tester.tap(find.text('1 / 5'));
      expect(taps, 1, reason: 'the hint never consumes media gestures');
      await tester.pump(const Duration(seconds: 2));
      await show(2);
      expect(find.text('2 / 5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(opacity(), 1, reason: 'changing Pages restarts the idle timeout');
      await show(2);
      await tester.pump(const Duration(seconds: 1));
      expect(
        opacity(),
        0,
        reason: 'unrelated rebuilds do not extend the timeout',
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(viewer.overlay.value, isFalse);
      expect(viewer.presentationProgress.value, 0);
      await show(5);
      await tester.pump(const Duration(milliseconds: 180));
      expect(opacity(), 1);
      expect(find.text('5 / 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
}
