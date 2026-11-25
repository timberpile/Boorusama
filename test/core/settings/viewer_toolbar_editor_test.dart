import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:boorusama/core/settings/src/widgets/viewer_toolbar_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

final _layout = ViewerToolbarLayout(
  toolbar: ViewerToolbarAction.values.take(5),
  more: ViewerToolbarAction.values.skip(5),
);

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Future<void> mount(
    WidgetTester tester,
    ValueNotifier<ViewerToolbarLayout> value, {
    double textScale = 1,
    TextDirection direction = TextDirection.ltr,
    Size size = const Size(440, 850),
    Set<ViewerToolbarAction>? availableActions,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: Directionality(textDirection: direction, child: child!),
              ),
            ),
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: value,
                builder: (_, layout, _) => ViewerToolbarEditor(
                  layout: layout,
                  availableActions:
                      availableActions ?? ViewerToolbarAction.values.toSet(),
                  onChanged: (next) => value.value = next,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(ViewerToolbarAction action) => find.byKey(ValueKey(action));
  Finder handle(ViewerToolbarAction action) =>
      find.byKey(ValueKey('toolbar-drag-${action.name}'));

  Future<void> drag(
    WidgetTester tester,
    ViewerToolbarAction action,
    double targetY,
  ) async {
    final start = tester.getCenter(handle(action));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(0, targetY < start.dy ? -24 : 24));
    await tester.pumpAndSettle();
    await gesture.moveTo(Offset(start.dx, targetY));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('drag reorders an action inside the toolbar', (tester) async {
    final value = ValueNotifier(_layout);
    await mount(tester, value);
    final indexBefore = value.value.toolbar.indexOf(
      ViewerToolbarAction.bookmark,
    );
    await drag(
      tester,
      ViewerToolbarAction.bookmark,
      tester.getTopLeft(row(ViewerToolbarAction.comments)).dy - 12,
    );
    expect(
      value.value.toolbar.indexOf(ViewerToolbarAction.bookmark),
      lessThan(indexBefore),
    );
    expect(value.value.more, isNot(contains(ViewerToolbarAction.bookmark)));
  });

  testWidgets('a 360 dp editor previews all five available toolbar actions', (
    tester,
  ) async {
    final value = ValueNotifier(_layout);
    await mount(tester, value, size: const Size(360, 780));
    for (final action in value.value.toolbar) {
      expect(
        find.byKey(ValueKey('viewer-toolbar-${action.name}')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('viewer-toolbar-more')), findsOneWidget);
  });

  testWidgets(
    'drag moves actions between Toolbar and More in both directions',
    (
      tester,
    ) async {
      final value = ValueNotifier(_layout);
      await mount(tester, value);
      await drag(
        tester,
        ViewerToolbarAction.share,
        tester.getBottomLeft(row(ViewerToolbarAction.upvote)).dy,
      );
      expect(value.value.toolbar, isNot(contains(ViewerToolbarAction.share)));
      expect(value.value.more, contains(ViewerToolbarAction.share));
      await drag(
        tester,
        ViewerToolbarAction.share,
        tester.getTopLeft(row(ViewerToolbarAction.comments)).dy - 40,
      );
      expect(value.value.toolbar.first, ViewerToolbarAction.share);
      expect(value.value.more, isNot(contains(ViewerToolbarAction.share)));
    },
  );

  testWidgets('dropping before a full toolbar slot swaps the chosen action', (
    tester,
  ) async {
    final value = ValueNotifier(_layout);
    await mount(tester, value);
    await drag(
      tester,
      ViewerToolbarAction.upvote,
      tester.getTopLeft(row(ViewerToolbarAction.comments)).dy - 40,
    );
    expect(value.value.toolbar.first, ViewerToolbarAction.upvote);
    expect(value.value.more.first, ViewerToolbarAction.comments);
    expect(value.value.toolbar.length, 5);
  });

  testWidgets('narrow enlarged RTL layout keeps the drag handles reachable', (
    tester,
  ) async {
    final value = ValueNotifier(_layout);
    await mount(
      tester,
      value,
      size: const Size(320, 640),
      textScale: 2,
      direction: TextDirection.rtl,
      availableActions: ViewerToolbarAction.values.toSet()
        ..remove(ViewerToolbarAction.upvote),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      row(ViewerToolbarAction.tagHistory),
      160,
    );
    await tester.pumpAndSettle();
    expect(
      handle(ViewerToolbarAction.tagHistory).hitTestable(
        at: const Alignment(-0.75, 0),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
