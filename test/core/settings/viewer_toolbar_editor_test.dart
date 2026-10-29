import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:boorusama/core/settings/src/widgets/viewer_toolbar_editor.dart';
import 'package:kurumi/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  Future<void> mount(
    WidgetTester tester,
    ValueNotifier<ViewerToolbarLayout> value, {
    double textScale = 1,
    TextDirection direction = TextDirection.ltr,
  }) => tester.pumpWidget(
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
              builder: (_, layout, _) => SingleChildScrollView(
                child: ViewerToolbarEditor(
                  layout: layout,
                  onChanged: (next) => value.value = next,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('accessible controls reorder and transfer the selected action', (
    tester,
  ) async {
    final value = ValueNotifier(ViewerToolbarLayout.editorDefault());
    addTearDown(value.dispose);
    await mount(tester, value);
    await tester.tap(find.byKey(const Key('edit-toolbar-bookmark')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('toolbar-move-back')));
    await tester.tap(find.byKey(const Key('toolbar-move-back')));
    await tester.pump();
    expect(value.value.toolbar[1], ViewerToolbarAction.bookmark);
    await tester.tap(find.byKey(const Key('toolbar-transfer')));
    await tester.pump();
    expect(value.value.toolbar, isNot(contains(ViewerToolbarAction.bookmark)));
    expect(value.value.more, contains(ViewerToolbarAction.bookmark));
    await tester.tap(find.byKey(const Key('toolbar-transfer')));
    await tester.pump();
    expect(value.value.toolbar.last, ViewerToolbarAction.bookmark);
  });

  testWidgets('full toolbar requires an explicit replacement target', (
    tester,
  ) async {
    final value = ValueNotifier(ViewerToolbarLayout.editorDefault());
    addTearDown(value.dispose);
    await mount(tester, value);
    final item = find.byKey(const Key('edit-more-upvote'));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('toolbar-transfer')));
    await tester.tap(find.byKey(const Key('toolbar-transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replace-toolbar-comments')));
    await tester.pumpAndSettle();
    expect(value.value.toolbar.first, ViewerToolbarAction.upvote);
    expect(value.value.more, contains(ViewerToolbarAction.comments));
    expect(value.value.toolbar.length, 5);
  });

  testWidgets('long press drag moves a toolbar action into More', (
    tester,
  ) async {
    final value = ValueNotifier(ViewerToolbarLayout.editorDefault());
    addTearDown(value.dispose);
    await mount(tester, value);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('edit-toolbar-bookmark'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('toolbar-more-drop'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(value.value.toolbar, isNot(contains(ViewerToolbarAction.bookmark)));
    expect(value.value.more.first, ViewerToolbarAction.bookmark);
  });

  testWidgets('320 dp and enlarged text preserve reachable controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final value = ValueNotifier(ViewerToolbarLayout.editorDefault());
    addTearDown(value.dispose);
    await mount(tester, value, textScale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('edit-more-tagHistory')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('RTL move controls follow the physical slot order', (
    tester,
  ) async {
    final value = ValueNotifier(ViewerToolbarLayout.editorDefault());
    addTearDown(value.dispose);
    await mount(tester, value, direction: TextDirection.rtl);
    await tester.tap(find.byKey(const Key('edit-toolbar-bookmark')));
    await tester.pump();
    final back = find.byKey(const Key('toolbar-move-back'));
    final icon = tester.widget<Icon>(
      find.descendant(of: back, matching: find.byType(Icon)),
    );
    expect(icon.textDirection, TextDirection.ltr);
    await tester.tap(back);
    await tester.pump();
    expect(value.value.toolbar[1], ViewerToolbarAction.bookmark);
    expect(tester.takeException(), isNull);
  });
}
