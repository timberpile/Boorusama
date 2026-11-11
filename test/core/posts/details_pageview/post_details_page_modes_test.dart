import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  Future<PostDetailsPageViewController> mount(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    Size media = const Size(800, 800),
    bool hideOverlay = false,
    bool reduceMotion = true,
    double textScale = 1,
    VoidCallback? onAction,
    FocusNode? detailsFocus,
    bool largeScreen = false,
    SheetStateStorage? storage,
    double? inheritedBottomPadding,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 8,
      checkIfLargeScreen: () => largeScreen,
      initialHideOverlay: hideOverlay,
      disableAnimation: reduceMotion,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    await tester.pumpWidget(
      _Harness(
        controller: controller,
        media: media,
        reduceMotion: reduceMotion,
        textScale: textScale,
        onAction: onAction,
        detailsFocus: detailsFocus,
        largeScreen: largeScreen,
        storage: storage,
        inheritedBottomPadding: inheritedBottomPadding,
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'large-screen Details restores and saves the existing expanded preference',
    (tester) async {
      final saved = <bool>[];
      final controller = await mount(
        tester,
        size: const Size(1200, 800),
        largeScreen: true,
        storage: SheetStateStorageBuilder(
          load: () => true,
          save: (value) async {
            saved.add(value);
          },
        ),
      );
      expect(controller.isExpanded, isTrue);
      await controller.resetSheet();
      await tester.pumpAndSettle();
      expect(saved.last, isFalse);
      await controller.expandToSnapPoint();
      await tester.pumpAndSettle();
      expect(saved.last, isTrue);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('hidden overlay hides top controls, reduced=$reduced', (
      tester,
    ) async {
      final controller = await mount(
        tester,
        hideOverlay: true,
        reduceMotion: reduced,
      );
      expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsNothing);
      controller.toggleOverlay();
      await tester.pumpAndSettle();
      expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsOneWidget);
      controller.toggleOverlay();
      await tester.pumpAndSettle();
      expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsNothing);
      await controller.expandToSnapPoint();
      await tester.pumpAndSettle();
      expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsNothing);
    });
  }

  for (final reduced in [false, true]) {
    for (final key in [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.tab]) {
      testWidgets(
        'keyboard ${key.keyLabel} reveals hidden controls, reduced=$reduced',
        (tester) async {
          final controller = await mount(
            tester,
            hideOverlay: true,
            reduceMotion: reduced,
          );
          expect(controller.overlay.value, isFalse);
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
          expect(controller.overlay.value, isTrue);
          expect(
            find.byType(KurumiInfoCircleIcon).hitTestable(),
            findsOneWidget,
          );
          final focused = FocusManager.instance.primaryFocus!;
          expect(focused.debugLabel, isNot('PostDetailsPage'));
          expect(visibleFocusRect(focused).isEmpty, isFalse);
        },
      );
    }
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'returning to Immersive releases hidden Details focus, reduced=$reduced',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var actions = 0;
        final controller = await mount(
          tester,
          hideOverlay: true,
          reduceMotion: reduced,
          detailsFocus: focus,
          onAction: () => actions++,
        );
        await controller.expandToSnapPoint();
        await tester.pumpAndSettle();
        focus.requestFocus();
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        await controller.resetSheet();
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        await tester.pumpAndSettle();
        focus.requestFocus();
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(actions, 0);
        expect(focus.hasFocus, isFalse);
      },
    );
  }

  for (final fromDetails in [false, true]) {
    testWidgets(
      'near-end release still has a visible snap animation, Details=$fromDetails',
      (tester) async {
        final controller = await mount(tester, reduceMotion: false);
        if (fromDetails) {
          await controller.expandToSnapPoint();
          await tester.pumpAndSettle();
        }
        double progress() => tester
            .widgetList<ViewerPresentationTransition>(
              find.byType(ViewerPresentationTransition),
            )
            .first
            .progress;
        final gesture = await tester.startGesture(
          Offset(200, fromDetails ? 200 : 500),
        );
        await gesture.moveBy(Offset(0, fromDetails ? 360 : -360));
        await tester.pump();
        final held = progress();
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        expect(progress(), inExclusiveRange(0, 1));
        expect(progress(), fromDetails ? lessThan(held) : greaterThan(held));
        await tester.pumpAndSettle();
        expect(progress(), fromDetails ? 0 : 1);
      },
    );
  }

  testWidgets(
    'synthetic app-navigation obstruction never becomes system padding',
    (tester) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      final controller = await mount(tester, inheritedBottomPadding: 80);
      await controller.expandToSnapPoint();
      await tester.pumpAndSettle();
      final viewport = find.byKey(const ValueKey(('viewer-safe-viewport', 0)));
      expect(tester.getRect(viewport).bottom, 776);
      await tester.pumpWidget(
        _Harness(
          controller: controller,
          media: const Size(800, 800),
          reduceMotion: true,
          textScale: 1,
          inheritedBottomPadding: 24,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport).bottom, 776);
    },
  );

  for (final fromDetails in [false, true]) {
    testWidgets(
      'release animates remaining mode travel, Details=$fromDetails',
      (tester) async {
        final controller = await mount(tester, reduceMotion: false);
        if (fromDetails) {
          await controller.expandToSnapPoint();
          await tester.pumpAndSettle();
        }
        double progress() => tester
            .widgetList<ViewerPresentationTransition>(
              find.byType(ViewerPresentationTransition),
            )
            .first
            .progress;
        final gesture = await tester.startGesture(
          Offset(200, fromDetails ? 200 : 500),
        );
        await gesture.moveBy(Offset(0, fromDetails ? 110 : -110));
        await tester.pump();
        final held = progress();
        expect(held, inExclusiveRange(0, 1));
        await gesture.up();
        await tester.pump();
        expect(progress(), closeTo(held, .001));
        await tester.pump(const Duration(milliseconds: 35));
        expect(progress(), inExclusiveRange(0, 1));
        expect(progress(), fromDetails ? lessThan(held) : greaterThan(held));
        await tester.pumpAndSettle();
        expect(progress(), fromDetails ? 0 : 1);
      },
    );
  }

  testWidgets('bottom overlay slides out and back in with top chrome', (
    tester,
  ) async {
    final controller = await mount(tester, reduceMotion: false);
    final footer = find.byKey(const Key('footer-0'));
    final visible = tester.getTopLeft(footer).dy;
    controller.hideAllUI();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getTopLeft(footer).dy, inExclusiveRange(visible, 800));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(footer).dy, greaterThanOrEqualTo(800));
    controller.showAllUI();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getTopLeft(footer).dy, inExclusiveRange(visible, 800));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(footer).dy, visible);
  });

  testWidgets('Info fades with the overlay and manual mode progress', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      reduceMotion: false,
      hideOverlay: true,
    );
    controller.showAllUI();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final info = find.byType(KurumiInfoCircleIcon);
    final opacity = tester
        .widget<Opacity>(
          find.ancestor(of: info, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(200, 500));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: info, matching: find.byType(Opacity)).first,
          )
          .opacity,
      closeTo(.5, .001),
    );
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(info.hitTestable(), findsNothing);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('mode gesture finishes hiding toolbar halfway through travel', (
    tester,
  ) async {
    final controller = await mount(tester, reduceMotion: false);
    final gesture = await tester.startGesture(const Offset(200, 500));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    final quarter = tester.getTopLeft(find.byKey(const Key('footer-0'))).dy;
    expect(quarter, inExclusiveRange(704, 800));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('footer-0'))).dy,
      greaterThanOrEqualTo(800),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getTopLeft(find.byKey(const Key('footer-0'))).dy,
      greaterThanOrEqualTo(800),
    );
    expect(controller.isExpanded, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('returning from Details starts Immersive with UI hidden', (
    tester,
  ) async {
    final controller = await mount(tester);
    await controller.expandToSnapPoint();
    await tester.pumpAndSettle();
    await controller.resetSheet();
    await tester.pumpAndSettle();
    expect(controller.overlay.value, isFalse);
    expect(controller.bottomSheet.value, isFalse);
  });

  testWidgets('overlay visibility never changes the media frame', (
    tester,
  ) async {
    final controller = await mount(tester);
    final frame = tester.getRect(find.byKey(const Key('art-0')));
    controller.toggleOverlay();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('art-0'))), frame);
    controller.toggleOverlay();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('art-0'))), frame);
  });

  for (final reduced in [false, true]) {
    for (final fromDetails in [false, true]) {
      testWidgets(
        'vertical transition follows finger and reversal before release, '
        'Details=$fromDetails reduced=$reduced',
        (tester) async {
          final controller = await mount(
            tester,
            hideOverlay: true,
            reduceMotion: reduced,
          );
          if (fromDetails) {
            await controller.expandToSnapPoint();
            await tester.pumpAndSettle();
          }
          final origin = Offset(200, fromDetails ? 200 : 500);
          final gesture = await tester.startGesture(origin);
          final direction = fromDetails ? 1.0 : -1.0;
          await gesture.moveBy(Offset(0, direction * 40));
          await tester.pump();
          final first = tester
              .getTopLeft(find.byKey(const Key('metadata-0')))
              .dy;
          await gesture.moveBy(Offset(0, direction * 35));
          await tester.pump();
          final second = tester
              .getTopLeft(find.byKey(const Key('metadata-0')))
              .dy;
          expect(second - first, closeTo(direction * 35, .01));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.getTopLeft(find.byKey(const Key('metadata-0'))).dy,
            second,
            reason: 'Holding the finger must not start a mode animation',
          );
          await gesture.moveBy(Offset(0, -direction * 25));
          await tester.pump();
          expect(
            tester.getTopLeft(find.byKey(const Key('metadata-0'))).dy - second,
            closeTo(-direction * 25, .01),
          );
          expect(controller.isExpanded, fromDetails);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(
            controller.isExpanded,
            fromDetails,
            reason: 'A 50px release returns to the starting mode',
          );
          final committed = await tester.startGesture(origin);
          await committed.moveBy(Offset(0, direction * 110));
          await tester.pump();
          expect(controller.isExpanded, fromDetails);
          await committed.up();
          await tester.pumpAndSettle();
          expect(controller.isExpanded, !fromDetails);
          expect(controller.animating.value, isFalse);
        },
      );
    }
  }

  testWidgets(
    'Details clips to stable system insets while Immersive stays full bleed',
    (tester) async {
      tester.view.viewPadding = const FakeViewPadding(
        left: 12,
        top: 28,
        right: 20,
        bottom: 24,
      );
      final controller = await mount(tester);
      final viewport = find.byKey(const ValueKey(('viewer-safe-viewport', 0)));
      expect(tester.getRect(viewport), const Rect.fromLTWH(0, 0, 400, 800));
      await controller.expandToSnapPoint();
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), const Rect.fromLTRB(12, 28, 380, 776));
      final art = tester.getRect(find.byKey(const Key('art-0')));
      expect(art.left, greaterThanOrEqualTo(12));
      expect(art.top, greaterThanOrEqualTo(28));
      expect(art.right, lessThanOrEqualTo(380));
      expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsNothing);
      tester.view.viewPadding = FakeViewPadding.zero;
      await tester.pump();
      expect(tester.getRect(viewport), const Rect.fromLTRB(12, 28, 380, 776));
      await controller.resetSheet();
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), const Rect.fromLTWH(0, 0, 400, 800));
      controller.showAllUI();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(KurumiInfoCircleIcon)).dy,
        greaterThanOrEqualTo(28),
      );
    },
  );

  testWidgets('upward image swipe enters Details without a visible overlay', (
    tester,
  ) async {
    final controller = await mount(tester, hideOverlay: true);
    await tester.dragFrom(const Offset(200, 350), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    expect(find.byKey(const Key('metadata-0')), findsOneWidget);
  });

  testWidgets(
    'toolbar drag moves artwork and footer together without activating its action',
    (tester) async {
      var actions = 0;
      final controller = await mount(tester, onAction: () => actions++);
      final art = tester.getTopLeft(find.byKey(const Key('art-0')));
      final footer = tester.getTopLeft(find.byKey(const Key('footer-0')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('action-0'))),
      );
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-76, 0));
      await tester.pump();
      final artworkDelta =
          tester.getTopLeft(find.byKey(const Key('art-0'))) - art;
      final footerDelta =
          tester.getTopLeft(find.byKey(const Key('footer-0'))) - footer;
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(artworkDelta.dx, lessThan(-40));
      expect(footerDelta.dx, closeTo(artworkDelta.dx, 0.01));
      expect(actions, 0);
      expect(controller.page, 0);
      expect(tester.getTopLeft(find.byKey(const Key('art-0'))), art);
      expect(actions, 0);
      await tester.tap(find.byKey(const Key('action-0')));
      expect(actions, 1);
    },
  );

  testWidgets('zoomed media still permits the upward toolbar Details gesture', (
    tester,
  ) async {
    final controller = await mount(tester);
    controller.zoom.value = true;
    controller.disableAllSwiping();
    await tester.pump();
    await tester.drag(find.byKey(const Key('footer-0')), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    expect(controller.zoom.value, isFalse);
  });

  for (final viewport in [
    const Size(320, 640),
    const Size(414, 915),
    const Size(844, 390),
  ]) {
    for (final media in [
      const Size(800, 800),
      const Size(800, 1400),
      const Size(4000, 300),
      const Size(500, 4000),
    ]) {
      testWidgets(
        'adaptive Details contains $media within its ceiling at $viewport',
        (tester) async {
          final controller = await mount(
            tester,
            size: viewport,
            media: media,
            textScale: 2,
          );
          await controller.expandToSnapPoint();
          await tester.pumpAndSettle();
          final block = tester.getRect(
            find.byKey(const ValueKey(('viewer-media', 0))),
          );
          final art = tester.getRect(find.byKey(const Key('art-0')));
          expect(block.height, lessThanOrEqualTo(viewport.height * 0.6 + 0.01));
          expect(art.top, greaterThanOrEqualTo(-0.01));
          expect(art.bottom, lessThanOrEqualTo(block.bottom + 0.01));
          expect(art.left, greaterThanOrEqualTo(-0.01));
          expect(art.right, lessThanOrEqualTo(viewport.width + 0.01));
          expect(
            art.width / art.height,
            closeTo(media.width / media.height, 0.001),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Details scroll removes media, and a new pull at the top returns to Immersive',
    (tester) async {
      final controller = await mount(tester);
      await controller.expandToSnapPoint();
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(200, 600), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomLeft(find.byKey(const Key('art-0'), skipOffstage: false))
            .dy,
        lessThan(0),
      );
      expect(controller.isExpanded, isTrue);
      controller.scrollDetailsToTop!();
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(200, 150), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isFalse);
    },
  );

  for (final onMedia in [true, false]) {
    testWidgets(
      'Details drag moves media and metadata continuously, media region=$onMedia',
      (tester) async {
        final controller = await mount(tester);
        await controller.expandToSnapPoint();
        await tester.pumpAndSettle();
        final art = tester.getTopLeft(find.byKey(const Key('art-0')));
        final metadata = tester.getTopLeft(find.byKey(const Key('metadata-0')));
        final gesture = await tester.startGesture(
          Offset(300, onMedia ? 180 : 600),
        );
        await gesture.moveBy(const Offset(-24, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-66, 0));
        await tester.pump();
        final artDelta =
            tester.getTopLeft(find.byKey(const Key('art-0'))) - art;
        final metaDelta =
            tester.getTopLeft(find.byKey(const Key('metadata-0'))) - metadata;
        await gesture.moveBy(const Offset(-210, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(artDelta.dx, lessThan(-30));
        expect(metaDelta.dx, closeTo(artDelta.dx, 0.01));
        expect(controller.isExpanded, isTrue);
        expect(controller.page, 1);
        expect(controller.isExpanded, isTrue);
        expect(find.byKey(const Key('metadata-1')), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Details restores an occurrence scroll checkpoint after distant navigation',
    (tester) async {
      final controller = await mount(tester);
      await controller.expandToSnapPoint();
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey(('viewer-details-scroll', 0))),
          )
          .controller!;
      scroll.jumpTo(650);
      await tester.pump();
      controller.jumpToPage(6);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('art-0')), findsNothing);
      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      final restored = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey(('viewer-details-scroll', 0))),
          )
          .controller!;
      expect(restored.offset, 650);
      expect(controller.isExpanded, isTrue);
    },
  );
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.controller,
    required this.media,
    required this.reduceMotion,
    required this.textScale,
    this.onAction,
    this.detailsFocus,
    this.largeScreen = false,
    this.storage,
    this.inheritedBottomPadding,
  });
  final PostDetailsPageViewController controller;
  final Size media;
  final bool reduceMotion;
  final double textScale;
  final VoidCallback? onAction;
  final FocusNode? detailsFocus;
  final bool largeScreen;
  final SheetStateStorage? storage;
  final double? inheritedBottomPadding;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
    builder: (context, child) => KurumiTheme(
      data: KurumiThemeData.fromMaterial(Theme.of(context)),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: MediaQuery.paddingOf(context)
              .copyWith(bottom: inheritedBottomPadding),
          viewPadding: MediaQuery.viewPaddingOf(context)
              .copyWith(bottom: inheritedBottomPadding),
        ),
        child: TranslationProvider(child: child!),
      ),
    ),
    home: Scaffold(
      body: PostDetailsPageView(
        controller: controller,
        checkIfLargeScreen: () => largeScreen,
        sheetStateStorage: storage,
        disableAnimation: reduceMotion,
        itemCount: 8,
        mediaSizeBuilder: (_) => media,
        itemBuilder: (context, index) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.isExpanded
              ? controller.resetSheet()
              : controller.toggleOverlay(),
          child: FittedBox(
            child: SizedBox(
              key: Key('art-$index'),
              width: media.width,
              height: media.height,
              child: ColoredBox(
                color: index.isEven ? Colors.blue : Colors.green,
              ),
            ),
          ),
        ),
        bottomPreviewBuilder: (context, index) => SizedBox(
          key: Key('footer-$index'),
          height: 96,
          width: double.infinity,
          child: TextButton(
            key: Key('action-$index'),
            onPressed: onAction,
            child: Text('Action $index'),
          ),
        ),
        detailsSliversBuilder: (context, index) => [
          SliverToBoxAdapter(
            child: SizedBox(
              key: Key('metadata-$index'),
              height: 64,
              child: TextButton(
                key: Key('details-action-$index'),
                focusNode: index == 0 ? detailsFocus : null,
                onPressed: onAction,
                child: Text('Post $index'),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: 30,
            itemBuilder: (context, row) =>
                SizedBox(height: 64, child: Text('Metadata $index row $row')),
          ),
        ],
      ),
    ),
  );
}
