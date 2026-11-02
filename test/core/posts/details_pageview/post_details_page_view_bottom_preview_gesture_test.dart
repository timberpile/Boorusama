import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/details_pageview/src/sheet_dragline.dart';

const _bottomPreviewKey = Key('bottom-preview');
const _mediaControlKey = Key('media-control');

void main() {
  for (final animated in [false, true]) {
    testWidgets(
      'viewer reports measured visible preview obstruction, animated=$animated',
      (tester) async {
        final controller = _controller(disableAnimation: !animated);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(controller: controller, disableAnimation: !animated),
        );
        await tester.pumpAndSettle();
        expect(controller.bottomObstruction.value, 96);
        controller.hideBottomSheet();
        await tester.pump();
        if (animated) {
          await tester.pump(const Duration(milliseconds: 75));
          expect(controller.bottomObstruction.value, greaterThan(0));
          expect(controller.bottomObstruction.value, lessThan(96));
        }
        await tester.pumpAndSettle();
        expect(controller.bottomObstruction.value, 0);
        controller.showBottomSheet();
        await tester.pumpAndSettle();
        expect(controller.bottomObstruction.value, 96);
        await tester.pumpWidget(
          _TestApp(
            controller: controller,
            disableAnimation: !animated,
            previewHeight: 144,
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.bottomObstruction.value, 144);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(controller.bottomObstruction.value, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets(
    'horizontal page navigation remains available above the preview',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_TestApp(controller: controller));

      expect(
        tester.widget<PageView>(find.byType(PageView)).scrollDirection,
        Axis.horizontal,
      );
      await tester.drag(
        find.byKey(const Key('viewer-page-0')),
        const Offset(-700, 0),
      );
      await tester.pumpAndSettle();

      expect(controller.currentPage.value, 1);
      expect(controller.sheetState.value, SheetState.collapsed);
    },
  );

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

  for (final disabled in [true, false]) {
    testWidgets(
      'horizontal paging collapses expanded details (animations disabled: $disabled)',
      (
        tester,
      ) async {
        final controller = _controller(disableAnimation: disabled);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(controller: controller, disableAnimation: disabled),
        );
        await _expandDetails(tester, controller);

        await tester.dragFrom(const Offset(300, 120), const Offset(-250, 0));
        await tester.pumpAndSettle();

        expect(controller.currentPage.value, 1);
        expect(controller.sheetState.value, SheetState.collapsed);
        expect(controller.sheetController.size, 0);
        expect(controller.displacement.value, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final disabled in [true, false]) {
    testWidgets(
      'clear swipe over details pages and collapses (animations disabled: $disabled)',
      (tester) async {
        final controller = _controller(disableAnimation: disabled);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            controller: controller,
            disableAnimation: disabled,
            scrollableDetails: true,
          ),
        );
        await _expandDetails(tester, controller);
        await tester.dragFrom(const Offset(300, 600), const Offset(-180, 12));
        await tester.pumpAndSettle();
        expect(controller.page, 1);
        expect(controller.sheetState.value, SheetState.collapsed);
        expect(controller.sheetController.size, 0);
        await _expandDetails(tester, controller);
        await tester.dragFrom(const Offset(100, 600), const Offset(180, -12));
        await tester.pumpAndSettle();
        expect(controller.page, 0);
        expect(controller.sheetState.value, SheetState.collapsed);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final offset in [
    const Offset(-30, 0),
    const Offset(-120, -90),
    const Offset(0, -180),
  ]) {
    testWidgets('details reject unclear sideways intent $offset', (
      tester,
    ) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _TestApp(controller: controller, scrollableDetails: true),
      );
      await _expandDetails(tester, controller);
      await tester.dragFrom(const Offset(300, 600), offset);
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      expect(controller.sheetState.value, SheetState.expanded);
      if (offset.dy < 0) {
        expect(
          tester
              .widget<ListView>(find.byKey(const Key('details-scroll')))
              .controller!
              .offset,
          greaterThan(0),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final block in [
    'zoom',
    'swiping disabled',
    'animation',
  ]) {
    testWidgets('details content preserves $block restriction', (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _TestApp(
          controller: controller,
          scrollableDetails: true,
        ),
      );
      await _expandDetails(tester, controller);
      if (block == 'zoom') controller.zoom.value = true;
      if (block == 'swiping disabled') controller.disableAllSwiping();
      if (block == 'animation') controller.animating.value = true;
      await tester.pump();
      await tester.dragFrom(const Offset(300, 600), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      expect(controller.sheetState.value, SheetState.expanded);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('details swipe cancels on multi-touch and when zoom changes', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestApp(controller: controller, scrollableDetails: true),
    );
    await _expandDetails(tester, controller);
    final first = await tester.startGesture(const Offset(300, 600), pointer: 1);
    await first.moveBy(const Offset(-60, 0));
    final second = await tester.startGesture(
      const Offset(260, 650),
      pointer: 2,
    );
    await first.moveBy(const Offset(-80, 0));
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    final interrupted = await tester.startGesture(const Offset(300, 600));
    await interrupted.moveBy(const Offset(-25, 0));
    controller.zoom.value = true;
    await tester.pump();
    controller.zoom.value = false;
    await tester.pump();
    await interrupted.moveBy(const Offset(-140, 0));
    await interrupted.up();
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    expect(controller.sheetState.value, SheetState.expanded);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'details cancel vertical starts, reversed swipes, pointer cancellation and boundary swipes',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _TestApp(controller: controller, scrollableDetails: true),
      );
      await _expandDetails(tester, controller);
      // There is no previous page at the start.
      await tester.dragFrom(const Offset(100, 600), const Offset(180, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      for (final cancellation in ['vertical start', 'reversal', 'cancel']) {
        final gesture = await tester.startGesture(const Offset(300, 600));
        if (cancellation == 'vertical start') {
          await gesture.moveBy(const Offset(0, -40));
          await gesture.moveBy(const Offset(-140, 0));
          await gesture.up();
        } else if (cancellation == 'reversal') {
          await gesture.moveBy(const Offset(-80, 0));
          await gesture.moveBy(const Offset(80, 0));
          await gesture.up();
        } else {
          await gesture.moveBy(const Offset(-100, 0));
          await gesture.cancel();
        }
        await tester.pumpAndSettle();
        expect(controller.page, 0, reason: cancellation);
        expect(controller.sheetState.value, SheetState.expanded);
      }
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      await _expandDetails(tester, controller);
      // There is no next page at the end.
      await tester.dragFrom(const Offset(300, 600), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      expect(controller.sheetState.value, SheetState.expanded);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'details retain nested horizontal scrolling, taps and text selection at narrow width with enlarged text',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      final horizontal = ScrollController();
      addTearDown(horizontal.dispose);
      var taps = 0;
      await tester.pumpWidget(
        _TestApp(
          controller: controller,
          textScale: 2,
          detailsContent: Column(
            children: [
              TextButton(
                onPressed: () => taps++,
                child: const Text('Details action'),
              ),
              const SelectableText(
                'Select this metadata text without changing the post',
                key: Key('selectable-details'),
              ),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  key: const Key('nested-horizontal'),
                  controller: horizontal,
                  scrollDirection: Axis.horizontal,
                  child: const SizedBox(
                    width: 1200,
                    child: Text('Nested horizontal content'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await _expandDetails(tester, controller, size: const Size(320, 800));
      await tester.tap(find.text('Details action'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.drag(
        find.byKey(const Key('nested-horizontal')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(horizontal.offset, greaterThan(0));
      expect(controller.page, 0);
      final selectionGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('selectable-details'))),
      );
      await tester.pump(kLongPressTimeout);
      await selectionGesture.moveBy(const Offset(80, 0));
      await selectionGesture.up();
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.selection.isCollapsed, isFalse);
      expect(controller.page, 0);
      expect(controller.sheetState.value, SheetState.expanded);
      expect(tester.takeException(), isNull);
    },
  );

  for (final block in ['zoom', 'swiping disabled']) {
    testWidgets('expanded details preserve the $block paging restriction', (
      tester,
    ) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_TestApp(controller: controller));
      await _expandDetails(tester, controller);
      if (block == 'zoom') controller.zoom.value = true;
      if (block == 'swiping disabled') controller.disableAllSwiping();
      await tester.pump();
      await tester.dragFrom(
        const Offset(300, 120),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      expect(controller.sheetState.value, SheetState.expanded);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('details scrolling does not navigate to another post', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestApp(controller: controller, scrollableDetails: true),
    );
    await _expandDetails(tester, controller);
    final list = find.byKey(const Key('details-scroll'));
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.widget<ListView>(list).controller!.offset, greaterThan(0));
    expect(controller.page, 0);
    expect(controller.sheetState.value, SheetState.expanded);
    expect(tester.takeException(), isNull);
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
      disableAnimation: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: count,
        builder: (_, itemCount, _) => _TestApp(
          controller: controller,
          itemCount: itemCount,
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
      disableAnimation: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _TestApp(
        controller: controller,
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
  bool disableAnimation = true,
  bool isLargeScreen = false,
}) => PostDetailsPageViewController(
  initialPage: 0,
  totalPage: 2,
  checkIfLargeScreen: () => isLargeScreen,
  disableAnimation: disableAnimation,
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
  PostDetailsPageViewController controller, {
  Size size = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pump();
  final expansion = controller.expandToSnapPoint();
  await tester.pumpAndSettle();
  await expansion;
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.controller,
    this.itemCount = 2,
    this.previewHeight = 96,
    this.disableAnimation = true,
    this.isLargeScreen = false,
    this.scrollableDetails = false,
    this.detailsContent,
    this.textScale = 1,
    this.onPreviewTap,
    this.onMediaTap,
    this.onMediaDoubleTap,
    this.onMediaControlTap,
  });

  final PostDetailsPageViewController controller;
  final int itemCount;
  final double previewHeight;
  final bool disableAnimation;
  final bool isLargeScreen;
  final bool scrollableDetails;
  final Widget? detailsContent;
  final double textScale;
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
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: TranslationProvider(child: child!),
        ),
      ),
      home: Scaffold(
        body: PostDetailsPageView(
          controller: controller,
          checkIfLargeScreen: () => isLargeScreen,
          disableAnimation: disableAnimation,
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
          sheetBuilder: (context, scrollController) => detailsContent != null
              ? SingleChildScrollView(
                  controller: scrollController,
                  child: detailsContent,
                )
              : scrollableDetails
              ? ListView.builder(
                  key: const Key('details-scroll'),
                  controller: scrollController,
                  itemCount: 40,
                  itemBuilder: (_, index) => SizedBox(
                    height: 60,
                    child: Text('Metadata $index'),
                  ),
                )
              : const ColoredBox(
                  color: Colors.white,
                  child: SizedBox.expand(),
                ),
          bottomSheet: SizedBox(
            key: _bottomPreviewKey,
            width: double.infinity,
            height: previewHeight,
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
