import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/search/types.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../application/support/fake_booru_backend.dart';
import 'following_topics/following_topic_test_utils.dart';

void main() {
  for (final searchPinned in [false, true]) {
    for (final toolbarPinned in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'attached Search motion searchPinned=$searchPinned '
          'toolbarPinned=$toolbarPinned scale=$scale',
          (tester) async {
            final fixture = _Fixture(searchPinned, toolbarPinned);
            addTearDown(fixture.dispose);
            await fixture.mount(tester, scale: scale);
            final position = fixture.position(tester);
            final controller = fixture.controller(tester);
            final editorState = tester.state<EditableTextState>(
              find.byType(EditableText).first,
            );
            final requests = fixture.requests;
            position.jumpTo(600);
            await tester.pumpAndSettle();
            expect(fixture.editor(tester).top, 0);
            expect(fixture.toolbar(tester).top, fixture.editor(tester).bottom);

            final gesture = await tester.startGesture(const Offset(160, 450));
            await gesture.moveBy(const Offset(0, -20));
            await tester.pump();
            final editorBefore = fixture.editor(tester);
            final toolbarBefore = fixture.toolbar(tester);
            final pixelsBefore = position.pixels;
            final tile = fixture.visibleTile(tester);
            final tileBefore = tester.getTopLeft(tile).dy;
            await gesture.moveBy(const Offset(0, -24));
            await tester.pump();
            final delta = position.pixels - pixelsBefore;
            expect(delta, closeTo(24, .01));
            expect(tester.getTopLeft(tile).dy - tileBefore, closeTo(-24, .01));
            if (!searchPinned && !toolbarPinned) {
              expect(
                fixture.editor(tester).top - editorBefore.top,
                closeTo(-delta, .01),
              );
              expect(
                fixture.toolbar(tester).top - toolbarBefore.top,
                closeTo(-delta, .01),
              );
              fixture.expectAttached(tester);
            } else if (searchPinned) {
              expect(fixture.editor(tester).top, editorBefore.top);
            }

            await gesture.moveBy(const Offset(0, -220));
            await tester.pump();
            // Holding before release avoids a fling; test time drives the snap.
            await tester.pump(const Duration(milliseconds: 200));
            await gesture.up();
            await tester.pumpAndSettle();
            expect(
              find.byType(RawSearchRegion).hitTestable(),
              searchPinned ? findsOneWidget : findsNothing,
            );
            expect(
              find.byType(PostListConfigurationHeader).hitTestable(),
              toolbarPinned ? findsOneWidget : findsNothing,
            );
            if (!searchPinned && !toolbarPinned) fixture.expectAttached(tester);

            final reverse = await tester.startGesture(const Offset(160, 450));
            await reverse.moveBy(const Offset(0, 20));
            await tester.pump();
            final reverseTile = fixture.visibleTile(tester);
            final reverseTileBefore = tester.getTopLeft(reverseTile).dy;
            final reverseEditorBefore = fixture.editor(tester).top;
            await reverse.moveBy(const Offset(0, 36));
            await tester.pump();
            expect(
              tester.getTopLeft(reverseTile).dy - reverseTileBefore,
              closeTo(36, .01),
            );
            if (!searchPinned && !toolbarPinned) {
              expect(
                fixture.editor(tester).top - reverseEditorBefore,
                closeTo(36, .01),
              );
              fixture.expectAttached(tester);
            }
            await tester.pump(const Duration(milliseconds: 200));
            await reverse.up();
            for (var frame = 0; frame < 8; frame++) {
              await tester.pump(const Duration(milliseconds: 40));
              if (!searchPinned && !toolbarPinned) {
                fixture.expectAttached(tester);
              }
            }
            await tester.pumpAndSettle();
            expect(fixture.position(tester), same(position));
            expect(fixture.controller(tester), same(controller));
            expect(
              tester.state(find.byType(EditableText).first),
              same(editorState),
            );
            expect(fixture.requests, requests);
            position.jumpTo(0);
            await tester.pumpAndSettle();
            expect(fixture.editor(tester).top, 0);
            fixture.expectAttached(tester);
            final firstTile = tester.getRect(find.text('Post 0'));
            expect(
              firstTile.top,
              greaterThanOrEqualTo(fixture.toolbar(tester).bottom),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets('removing the source profile retires the hosted toolbar safely', (
    tester,
  ) async {
    final profiles = _Profiles();
    final fixture = _Fixture(
      false,
      false,
      overrides: [
        booruConfigProvider.overrideWith(() => profiles),
      ],
    );
    addTearDown(fixture.dispose);
    await fixture.mount(tester);
    profiles.withdraw();
    await tester.pumpAndSettle();
    expect(find.byType(PostListConfigurationHeader), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion snaps the attached panel immediately', (
    tester,
  ) async {
    final fixture = _Fixture(false, false, reduceMotion: true);
    addTearDown(fixture.dispose);
    await fixture.mount(tester);
    fixture.position(tester).jumpTo(600);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(160, 450));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    expect(fixture.editor(tester).top, lessThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump();
    expect(fixture.editor(tester).top, 0);
    fixture.expectAttached(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hosted toolbar Select uses the grid selection controller', (
    tester,
  ) async {
    final fixture = _Fixture(false, false);
    addTearDown(fixture.dispose);
    await fixture.mount(tester);
    final selection = SelectionMode.of(tester.element(find.text('Post 0')));
    await tester.tap(
      find.descendant(
        of: find.byType(PostListConfigurationHeader),
        matching: find.byType(KurumiPopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(selection.isActive, isTrue);
    expect(fixture.editor(tester).top, 0);
    fixture.expectAttached(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'interrupted snap resumes from rendered header and survives editing',
    (tester) async {
      final fixture = _Fixture(false, false);
      addTearDown(fixture.dispose);
      await fixture.mount(tester);
      final position = fixture.position(tester)..jumpTo(600);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(160, 450));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -70));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      fixture.expectAttached(tester);
      final reverse = await tester.startGesture(const Offset(160, 450));
      await reverse.moveBy(const Offset(0, 20));
      await tester.pump();
      final before = fixture.editor(tester).top;
      final pixels = position.pixels;
      await reverse.moveBy(const Offset(0, 12));
      await tester.pump();
      expect(
        fixture.editor(tester).top - before,
        closeTo(pixels - position.pixels, .01),
      );
      fixture.expectAttached(tester);
      final offset = position.pixels;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pump();
      fixture.expectAttached(tester);
      expect(position.pixels, offset);
      await reverse.up();
      await tester.pumpAndSettle();

      final search = InheritedSearchPageController.of(
        tester.element(find.byType(RawSearchRegion)),
      );
      for (final state in [SearchState.options, SearchState.suggestions]) {
        search.changeState(state);
        await tester.pumpAndSettle();
        expect(
          find.byType(PostListConfigurationHeader).hitTestable(),
          findsNothing,
        );
        expect(fixture.editor(tester).top, 0);
      }
      search.closeEditor();
      await tester.pumpAndSettle();
      fixture.expectAttached(tester);
      search.skipToResultWithTag('bird');
      await tester.pumpAndSettle();
      expect(fixture.requests, 2);
      fixture.expectAttached(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Fixture {
  _Fixture(
    this.searchPinned,
    this.toolbarPinned, {
    this.reduceMotion = false,
    this.overrides = const [],
  });
  final List<Override> overrides;
  final bool reduceMotion;
  final bool searchPinned;
  final bool toolbarPinned;
  late final harness = FollowingTopicHarness(
    overrides: overrides,
    settings: Settings.defaultSettings.copyWith(
      autoFocusSearchBar: false,
      reduceAnimations: reduceMotion,
      searchBarScrollBehavior: searchPinned
          ? SearchBarScrollBehavior.persistent
          : SearchBarScrollBehavior.autoHide,
    ),
    listingSettings: Settings.defaultSettings.listing.copyWith(
      keepTimelineToolbarVisible: toolbarPinned,
    ),
  );
  var requests = 0;

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.pump(
      tester,
      Scaffold(
        body: SearchPageScaffold<Post>(
          params: const SearchParams(query: 'cat dog'),
          landingViewBuilder: (_) => const SizedBox.shrink(),
          fetcher: (_, _) {
            requests++;
            return TaskEither.right(
              PostResult(
                posts: [for (var i = 0; i < 80; i++) TestPost(id: i + 1)],
                total: 80,
              ),
            );
          },
          itemBuilder: (_, index, _, _, _) => SizedBox(
            height: 180,
            child: Text('Post $index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(PostGrid<Post>),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      )
      .position;
  PostGridController<Post> controller(WidgetTester tester) =>
      PostScope.of<Post>(tester.element(find.byType(PostGrid<Post>)));
  Rect editor(WidgetTester tester) =>
      tester.getRect(find.byType(RawSearchRegion));
  Rect toolbar(WidgetTester tester) =>
      tester.getRect(find.byType(PostListConfigurationHeader));
  Finder visibleTile(WidgetTester tester) {
    final tiles = find.textContaining(RegExp(r'^Post \d+$'));
    return find.byWidget(
      tester.widgetList<Text>(tiles).firstWhere((tile) {
        final y = tester.getTopLeft(find.byWidget(tile)).dy;
        return y > 250 && y < 500;
      }),
    );
  }

  void expectAttached(WidgetTester tester) =>
      expect(toolbar(tester).top, closeTo(editor(tester).bottom, .01));
  void dispose() => harness.dispose();
}

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: [testProfile, otherTestProfile]);
  void withdraw() => state = [];
}
