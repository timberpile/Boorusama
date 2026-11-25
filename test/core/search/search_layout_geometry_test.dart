import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/search/types.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/selected_tags/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import 'following_topics/following_topic_test_utils.dart';

void main() {
  for (final placement in SearchBarPosition.values) {
    testWidgets('actual editor layout owns viewport at $placement', (
      tester,
    ) async {
      final fixture = _LayoutFixture(placement);
      addTearDown(fixture.dispose);
      await fixture.mount(tester);
      fixture.controller.skipToResultWithTag('cat');
      await tester.pumpAndSettle();
      final position = fixture.scroll.position;
      position.jumpTo(400);
      await tester.pumpAndSettle();
      fixture.expectAttached(tester);
      final shown = tester.getRect(find.byKey(_editor));
      expect(
        placement == SearchBarPosition.top ? shown.top : shown.bottom,
        placement == SearchBarPosition.top ? 0 : 600,
        reason: 'programmatic scroll restoration must not hide the editor',
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_results)),
      );
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      fixture.expectAttached(tester);
      final pixels = position.pixels;
      fixture.height.value = 128;
      await tester.pump();
      fixture.expectAttached(tester);
      await tester.pump();
      expect(position.pixels, pixels);
      expect(fixture.scroll.position, same(position));
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump();
      fixture.expectAttached(tester);
      await gesture.up();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        fixture.expectAttached(tester);
      }
      expect(fixture.builds, 1);
      expect(fixture.controller.tagString.value, 'cat');
      if (placement == SearchBarPosition.top) {
        final hide = await tester.startGesture(const Offset(160, 450));
        await hide.moveBy(const Offset(0, -200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await hide.up();
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(_editor)).bottom, 0);

        fixture.controller.skipToResultWithTag('dog');
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(_editor)).top, 0);
        expect(fixture.controller.tagString.value, 'dog');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('applied transparent route paints outside its SafeArea', (
    tester,
  ) async {
    final fixture = _LayoutFixture(SearchBarPosition.top);
    addTearDown(fixture.dispose);
    await fixture.mount(tester, topInset: 24);
    Future<Color> pixel([Offset point = const Offset(4, 4)]) async =>
        (await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_paint),
          );
          final image = await boundary.toImage();
          final bytes = (await image.toByteData())!;
          final offset =
              (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
          final color = Color.fromARGB(
            bytes.getUint8(offset + 3),
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          );
          image.dispose();
          return color;
        }))!;

    expect((await pixel()).toARGB32(), Colors.red.toARGB32());
    fixture.controller.skipToResultWithTag('cat');
    await tester.pumpAndSettle();
    expect((await pixel()).toARGB32(), isNot(Colors.red.toARGB32()));
    for (final status in [1, 2, 3, 0]) {
      fixture.surfaceState.value = status;
      await tester.pumpAndSettle();
      expect((await pixel()).toARGB32(), isNot(Colors.red.toARGB32()));
      expect(
        (await pixel(const Offset(160, 350))).toARGB32(),
        isNot(Colors.red.toARGB32()),
      );
    }
    for (final state in [
      SearchState.options,
      SearchState.suggestions,
      SearchState.initial,
    ]) {
      fixture.controller.changeState(state);
      await tester.pumpAndSettle();
      expect((await pixel()).toARGB32(), isNot(Colors.red.toARGB32()));
    }
    await tester.pumpWidget(const SizedBox());
  });
}

const _results = ValueKey('geometry-results');
const _editor = ValueKey('geometry-editor');
const _paint = ValueKey('geometry-paint');

class _LayoutFixture {
  _LayoutFixture(this.placement);
  final SearchBarPosition placement;
  final tags = SelectedTagController(metatagExtractor: null);
  late final controller = SearchPageController(
    tagsController: tags,
    textMatchers: null,
    metatagExtractor: null,
  );
  final selection = SelectionModeController();
  final height = ValueNotifier<double>(92);
  final scroll = ScrollController();
  final surfaceState = ValueNotifier(0);
  late final harness = FollowingTopicHarness(
    overrides: [searchBarPositionProvider.overrideWithValue(placement)],
  );
  var builds = 0;

  Future<void> mount(WidgetTester tester, {double topInset = 0}) async {
    await harness.pump(
      tester,
      RepaintBoundary(
        key: _paint,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            padding: EdgeInsets.only(top: topInset),
          ),
          child: Navigator(
            onDidRemovePage: (_) {},
            pages: [
              const MaterialPage<void>(child: ColoredBox(color: Colors.red)),
              CustomTransitionPage<void>(
                opaque: false,
                transitionDuration: Duration.zero,
                transitionsBuilder: (_, _, _, child) => child,
                child: RawSearchPageScaffold<Post>(
                  params: const SearchParams(),
                  tagsController: tags,
                  controller: controller,
                  selectionModeController: selection,
                  fetcher: (_, _) => throw StateError('Native results'),
                  onQueryChanged: (_) {},
                  onPostControllerCreated: (_) {},
                  searchRegion: ValueListenableBuilder(
                    valueListenable: height,
                    builder: (_, value, _) => SizedBox(
                      key: _editor,
                      height: value,
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                  searchSuggestions: const SizedBox.shrink(),
                  resultHeader: const SizedBox.shrink(),
                  landingView: const Text('Options'),
                  nativeResultBuilder: (_, _, _, _, _, _, leadingSliver) {
                    builds++;
                    return ValueListenableBuilder(
                      valueListenable: surfaceState,
                      builder: (_, status, _) => CustomScrollView(
                        key: _results,
                        controller: scroll,
                        slivers: [
                          ?leadingSliver,
                          if (status != 0)
                            SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  ['', 'Loading', 'Empty', 'Error'][status],
                                ),
                              ),
                            )
                          else
                            const SliverToBoxAdapter(
                              child: SizedBox(
                                height: 2400,
                                child: ColoredBox(color: Colors.green),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectAttached(WidgetTester tester) {
    final editor = tester.getRect(find.byKey(_editor));
    final viewport = tester.getRect(find.byKey(_results));
    expect(
      placement == SearchBarPosition.top ? viewport.top : viewport.bottom,
      closeTo(
        placement == SearchBarPosition.top ? 0 : editor.top,
        .5,
      ),
    );
  }

  void dispose() {
    harness.dispose();
    controller.dispose();
    tags.dispose();
    selection.dispose();
    height.dispose();
    scroll.dispose();
    surfaceState.dispose();
  }
}
