import 'package:boorusama/core/posts/details/src/widgets/media_group_page_indicator.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_page_view_scope.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_transformation_scope.dart';
import 'package:boorusama/core/posts/details/src/types/post_viewer_transformation_controller.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets('zoom leaves the canvas counter at the same position and size', (
    tester,
  ) async {
    final viewer = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    final transform = TransformationController();
    addTearDown(viewer.dispose);
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 600,
              child: PostDetailsPageViewScope(
                controller: viewer,
                child: PostViewerTransformationScope(
                  controller: PostViewerTransformationController(transform),
                  child: const ViewerMediaViewport(
                    viewport: Size(320, 600),
                    details: Size(320, 360),
                    progress: 0,
                    child: MediaGroupPageIndicator(
                      memberKey: 'portrait',
                      page: 1,
                      total: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final counter = find.byType(AnimatedOpacity);
    final labelSize = tester.getSize(counter);
    expect(tester.getBottomRight(counter), const Offset(312, 592));
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-100, -300, 0);
    await tester.pump();
    expect(tester.getBottomRight(counter), const Offset(312, 592));
    expect(tester.getSize(counter), labelSize);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reading hint belongs to the lower-right of its media host', (
    tester,
  ) async {
    final viewer = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    addTearDown(viewer.dispose);
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: PostDetailsPageViewScope(
                  controller: viewer,
                  child: const MediaGroupPageIndicator(
                    memberKey: 'member',
                    page: 2,
                    total: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final host = tester.getRect(find.byType(MediaGroupPageIndicator));
    final label = tester.getRect(find.byType(AnimatedOpacity));
    expect(label.bottomRight, host.bottomRight - const Offset(8, 8));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('counter follows the media canvas through the transition', (
    tester,
  ) async {
    final viewer = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    addTearDown(viewer.dispose);
    for (final progress in [0.0, .25, .5, .75, 1.0]) {
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  height: 600 - 240 * progress,
                  child: PostDetailsPageViewScope(
                    controller: viewer,
                    child: ViewerMediaViewport(
                      viewport: const Size(320, 600),
                      details: const Size(320, 360),
                      progress: progress,
                      child: MediaGroupPageIndicator(
                        memberKey: 'member',
                        page: 1,
                        total: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final expected = Offset(312, 592 - 240 * progress);
      if (progress == 0) {
        viewer.bottomObstruction.value = 240;
        await tester.pump();
        expect(
          tester.getBottomRight(find.byType(AnimatedOpacity)),
          const Offset(312, 352),
        );
        viewer.bottomObstruction.value = 0;
        await tester.pump();
      }
      expect(tester.getBottomRight(find.byType(AnimatedOpacity)), expected);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('counter scrolls with the first media sliver in Detailed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final viewer = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      disableAnimation: true,
      checkIfLargeScreen: () => false,
    );
    addTearDown(viewer.dispose);
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: PostDetailsPageViewScope(
            controller: viewer,
            child: PostDetailsPageView(
              controller: viewer,
              disableAnimation: true,
              checkIfLargeScreen: () => false,
              itemCount: 1,
              mediaNavigationBuilder: (_) => const MediaPageNavigation(),
              itemBuilder: (_, _) => const MediaGroupPageIndicator(
                memberKey: 'page',
                page: 1,
                total: 3,
              ),
              detailsSliversBuilder: (_, _) => const [
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await viewer.expandToSnapPoint();
    await tester.pump();
    final label = find.byType(AnimatedOpacity);
    final initial = tester.getBottomRight(label);
    final scroll = tester
        .widget<CustomScrollView>(
          find.byKey(const ValueKey(('viewer-details-scroll', 0))),
        )
        .controller!;
    scroll.jumpTo(100);
    await tester.pump();
    expect(tester.getBottomRight(label), initial - const Offset(0, 100));
    scroll.jumpTo(420);
    await tester.pump();
    expect(find.text('1 / 3'), findsNothing);
    await tester.pumpWidget(const SizedBox());
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
      await tester.tapAt(tester.getCenter(find.text('1 / 5')));
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
