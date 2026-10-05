import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/details_pageview/src/sheet_dragline.dart';

const _bottomPreviewKey = Key('bottom-preview');
const _mediaControlKey = Key('media-control');

void main() {
  testWidgets('an upward swipe on the bottom preview opens post information', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));

    await _dragBottomPreview(tester, const Offset(0, -80));

    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('an upward swipe opens information with animations enabled', (
    tester,
  ) async {
    final controller = _controller(disableAnimation: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestApp(
        controller: controller,
        disableAnimation: false,
      ),
    );

    await _dragBottomPreview(tester, const Offset(0, -80));

    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('a qualifying upward movement opens information before release', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    final center = tester.getCenter(find.byKey(_bottomPreviewKey));
    final gesture = await tester.startGesture(center);

    await gesture.moveBy(const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.expanded);
    await gesture.up();
  });

  final rejectedDrags = [
    (name: 'small upward', offset: const Offset(0, -20)),
    (name: 'downward', offset: const Offset(0, 80)),
    (name: 'horizontal', offset: const Offset(80, -8)),
    (name: 'diagonal', offset: const Offset(60, -80)),
  ];
  for (final drag in rejectedDrags) {
    testWidgets('${drag.name} drags on the bottom preview stay collapsed', (
      tester,
    ) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_TestApp(controller: controller));

      await _dragBottomPreview(tester, drag.offset);

      expect(controller.sheetState.value, SheetState.collapsed);
    });
  }

  testWidgets('a second pointer cancels a bottom preview swipe', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    final center = tester.getCenter(find.byKey(_bottomPreviewKey));
    final first = await tester.startGesture(center, pointer: 1);
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );

    await first.moveBy(const Offset(0, -80));
    await second.moveBy(const Offset(0, -80));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.collapsed);
  });

  testWidgets('a cancelled swipe stays cancelled until every pointer lifts', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    final center = tester.getCenter(find.byKey(_bottomPreviewKey));
    final first = await tester.startGesture(center, pointer: 1);
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await first.up();
    final third = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 3,
    );

    await third.moveBy(const Offset(0, -80));
    await third.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.collapsed);
  });

  testWidgets('bottom preview controls keep their tap behavior', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    var taps = 0;
    await tester.pumpWidget(
      _TestApp(
        controller: controller,
        onPreviewTap: () => taps++,
      ),
    );

    await tester.tap(find.byKey(const Key('preview-control')));
    await tester.pump();

    expect(taps, 1);
    expect(controller.sheetState.value, SheetState.collapsed);
  });

  testWidgets('the bottom preview is unavailable after information expands', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));

    await _dragBottomPreview(tester, const Offset(0, -80));

    expect(controller.sheetState.value, SheetState.expanded);
    expect(find.byKey(_bottomPreviewKey), findsNothing);
  });

  final navigationCases = [
    (
      name: 'horizontal',
      viewMode: ViewMode.horizontal,
      offset: const Offset(-700, 0),
    ),
    (
      name: 'vertical',
      viewMode: ViewMode.vertical,
      offset: const Offset(0, -400),
    ),
  ];
  for (final navigation in navigationCases) {
    testWidgets(
      '${navigation.name} page navigation remains available above the preview',
      (tester) async {
        final controller = _controller(viewMode: navigation.viewMode);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            controller: controller,
            viewMode: navigation.viewMode,
          ),
        );

        await tester.drag(
          find.byKey(const Key('viewer-page-0')),
          navigation.offset,
        );
        await tester.pumpAndSettle();

        expect(controller.currentPage.value, 1);
        expect(controller.sheetState.value, SheetState.collapsed);
      },
    );
  }

  testWidgets(
    'a downward swipe on expanded media minimizes before pointer release',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_TestApp(controller: controller));
      await _expandDetails(tester, controller);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('viewer-page-0'))),
      );

      await gesture.moveBy(const Offset(0, 80));
      await tester.pumpAndSettle();

      expect(controller.sheetState.value, SheetState.hidden);
      await gesture.up();
    },
  );

  testWidgets('a downward swipe on the details sheet still minimizes', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    await _expandDetails(tester, controller);

    await tester.drag(find.byType(SheetDragline), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, isNot(SheetState.expanded));
  });

  testWidgets(
    'a downward media swipe does nothing while details are collapsed',
    (
      tester,
    ) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_TestApp(controller: controller));

      await _dragMedia(tester, const Offset(0, 80));

      expect(controller.sheetState.value, SheetState.collapsed);
    },
  );

  testWidgets('a downward media swipe keeps zoomed details expanded', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    await _expandDetails(tester, controller);
    controller.zoom.value = true;
    await tester.pump();

    await _dragMedia(tester, const Offset(0, 80));

    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('a large-screen media swipe leaves the side panel expanded', (
    tester,
  ) async {
    final controller = _controller(isLargeScreen: true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestApp(controller: controller, isLargeScreen: true),
    );
    controller.sheetState.value = SheetState.expanded;
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(200, 300), const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.expanded);
    expect(controller.animating.value, isFalse);
  });

  final rejectedMediaDrags = [
    (name: 'small downward', offset: const Offset(0, 20)),
    (name: 'upward', offset: const Offset(0, -80)),
    (name: 'horizontal', offset: const Offset(80, 8)),
    (name: 'diagonal', offset: const Offset(60, 80)),
  ];
  for (final drag in rejectedMediaDrags) {
    testWidgets('${drag.name} drags on expanded media keep details open', (
      tester,
    ) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_TestApp(controller: controller));
      await _expandDetails(tester, controller);

      await _dragMedia(tester, drag.offset);

      expect(controller.sheetState.value, SheetState.expanded);
    });
  }

  testWidgets('a second pointer cancels an expanded media swipe', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    await _expandDetails(tester, controller);
    final center = tester.getCenter(find.byKey(const Key('viewer-page-0')));
    final first = await tester.startGesture(center, pointer: 1);
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );

    await first.moveBy(const Offset(0, 80));
    await second.moveBy(const Offset(0, 80));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('horizontal paging resumes after expanded details minimize', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    await _expandDetails(tester, controller);

    await tester.dragFrom(const Offset(300, 120), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(controller.currentPage.value, 0);

    await _dragMedia(tester, const Offset(0, 80));
    expect(controller.sheetState.value, SheetState.hidden);

    await tester.drag(
      find.byKey(const Key('viewer-page-0')),
      const Offset(-350, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.currentPage.value, 1);
  });

  testWidgets('a sheet state change cancels an in-progress media swipe', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    await _expandDetails(tester, controller);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('viewer-page-0'))),
    );
    await gesture.moveBy(const Offset(0, 20));
    controller.sheetState.value = SheetState.hidden;
    await tester.pump();
    controller.sheetState.value = SheetState.expanded;
    await tester.pump();

    await gesture.moveBy(const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.expanded);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('zoom changes cancel an in-progress media swipe', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_TestApp(controller: controller));
    await _expandDetails(tester, controller);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('viewer-page-0'))),
    );
    await gesture.moveBy(const Offset(0, 20));
    controller.zoom.value = true;
    controller.zoom.value = false;

    await gesture.moveBy(const Offset(0, 80));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('expanded media keeps tap and double tap behavior', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    var taps = 0;
    var doubleTaps = 0;
    await tester.pumpWidget(
      _TestApp(
        controller: controller,
        onMediaTap: () => taps++,
        onMediaDoubleTap: () => doubleTaps++,
      ),
    );
    await _expandDetails(tester, controller);

    final mediaTapPosition =
        tester.getTopLeft(find.byKey(const Key('viewer-page-0'))) +
        const Offset(300, 120);
    await tester.tapAt(mediaTapPosition);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(mediaTapPosition);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(mediaTapPosition);
    await tester.pump(const Duration(milliseconds: 400));

    expect(taps, 1);
    expect(doubleTaps, 1);
    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('expanded media controls keep their tap behavior', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    var controlTaps = 0;
    await tester.pumpWidget(
      _TestApp(
        controller: controller,
        onMediaControlTap: () => controlTaps++,
      ),
    );
    await _expandDetails(tester, controller);

    await tester.tap(find.byKey(_mediaControlKey));
    await tester.pump();

    expect(controlTaps, 1);
    expect(controller.sheetState.value, SheetState.expanded);
  });

  testWidgets('adding posts during an edge slide keeps the current post', (
    tester,
  ) async {
    final count = ValueNotifier(2);
    addTearDown(count.dispose);
    final controller = _controller(
      viewMode: ViewMode.vertical,
      disableAnimation: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: count,
        builder: (_, itemCount, _) => _TestApp(
          controller: controller,
          itemCount: itemCount,
          viewMode: ViewMode.vertical,
          disableAnimation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigation = tester.widget<ZoomPageNavigationScope>(
      find.byType(ZoomPageNavigationScope).first,
    );
    navigation.onEdgeNext!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_isPageFaded(tester, controller), isTrue);
    expect(controller.page, 0);

    controller.totalPage = 3;
    count.value = 3;
    await tester.pump();
    expect(_isPageFaded(tester, controller), isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.page, 0);
  });

  testWidgets('closing the viewer during an edge slide leaves no animation', (
    tester,
  ) async {
    final controller = _controller(
      viewMode: ViewMode.vertical,
      disableAnimation: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestApp(
        controller: controller,
        viewMode: ViewMode.vertical,
        disableAnimation: false,
      ),
    );
    await tester.pumpAndSettle();

    final navigation = tester.widget<ZoomPageNavigationScope>(
      find.byType(ZoomPageNavigationScope).first,
    );
    navigation.onEdgeNext!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_isPageFaded(tester, controller), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });
}

PostDetailsPageViewController _controller({
  ViewMode viewMode = ViewMode.horizontal,
  bool disableAnimation = true,
  bool isLargeScreen = false,
}) => PostDetailsPageViewController(
  initialPage: 0,
  totalPage: 2,
  checkIfLargeScreen: () => isLargeScreen,
  disableAnimation: disableAnimation,
  viewMode: viewMode,
);

bool _isPageFaded(
  WidgetTester tester,
  PostDetailsPageViewController controller,
) {
  final pageView = find.byWidgetPredicate(
    (widget) =>
        widget is PageView && widget.controller == controller.pageController,
  );
  return tester
      .widgetList<Opacity>(
        find.ancestor(of: pageView, matching: find.byType(Opacity)),
      )
      .any((opacity) => opacity.opacity < 1);
}

Future<void> _dragBottomPreview(
  WidgetTester tester,
  Offset offset,
) async {
  await tester.drag(find.byKey(_bottomPreviewKey), offset);
  await tester.pumpAndSettle();
}

Future<void> _dragMedia(
  WidgetTester tester,
  Offset offset,
) async {
  await tester.drag(find.byKey(const Key('viewer-page-0')), offset);
  await tester.pumpAndSettle();
}

Future<void> _expandDetails(
  WidgetTester tester,
  PostDetailsPageViewController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pump();
  await controller.expandToSnapPoint();
  await tester.pumpAndSettle();
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.controller,
    this.itemCount = 2,
    this.viewMode = ViewMode.horizontal,
    this.disableAnimation = true,
    this.isLargeScreen = false,
    this.onPreviewTap,
    this.onMediaTap,
    this.onMediaDoubleTap,
    this.onMediaControlTap,
  });

  final PostDetailsPageViewController controller;
  final int itemCount;
  final ViewMode viewMode;
  final bool disableAnimation;
  final bool isLargeScreen;
  final VoidCallback? onPreviewTap;
  final VoidCallback? onMediaTap;
  final VoidCallback? onMediaDoubleTap;
  final VoidCallback? onMediaControlTap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
      builder: (context, child) => KurumiTheme(
        data: KurumiThemeData.fromMaterial(Theme.of(context)),
        child: TranslationProvider(child: child!),
      ),
      home: Scaffold(
        body: PostDetailsPageView(
          controller: controller,
          checkIfLargeScreen: () => isLargeScreen,
          disableAnimation: disableAnimation,
          viewMode: viewMode,
          itemCount: itemCount,
          itemBuilder: (context, index) => GestureDetector(
            key: Key('viewer-page-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: onMediaTap,
            onDoubleTap: onMediaDoubleTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: index.isEven ? Colors.black : Colors.blueGrey,
                  ),
                ),
                Positioned(
                  top: 80,
                  left: 160,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: TextButton(
                      key: index == 0 ? _mediaControlKey : null,
                      onPressed: onMediaControlTap,
                      child: const Text('Control'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          sheetBuilder: (context, scrollController) => const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(),
          ),
          bottomSheet: SizedBox(
            key: _bottomPreviewKey,
            width: double.infinity,
            height: 96,
            child: TextButton(
              key: const Key('preview-control'),
              onPressed: onPreviewTap,
              child: const Text('Preview control'),
            ),
          ),
        ),
      ),
    );
  }
}
