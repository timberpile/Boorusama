import 'package:boorusama/core/groups/folder_navigation.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pin_search_dialog.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pin_search_folder_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  late String root;
  late String child;
  late String deep;
  final choices = <({String? id, bool isNew})>[];

  Future<void> initialize() async {
    choices.clear();
    harness = PinnedSearchHarness();
    addTearDown(harness.dispose);
    await harness.seed([]);
    final notifier = harness.container.read(
      searchSubscriptionsProvider.notifier,
    );
    root = (await notifier.createSharedFolder('Artists')).id;
    child = (await notifier.createSharedFolder('Cookie', parentId: root)).id;
    deep = (await notifier.createSharedFolder('Deep', parentId: child)).id;
    await notifier.createSharedFolder('Other');
  }

  Future<void> pump(WidgetTester tester, {String? initial, double scale = 1}) =>
      harness.pump(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 700),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: PinSearchDialog(
              query: 'cat',
              isPinned: initial != null,
              extra: PinSearchFolderPicker(
                initialFolderId: initial,
                onSelected: (id, isNew) => choices.add((id: id, isNew: isNew)),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(PinSearchFolderPicker));
    await tester.tap(find.byType(PinSearchFolderPicker));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Select'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows only direct folders and confirms a deeply nested destination',
    (tester) async {
      await initialize();
      await pump(tester);
      await open(tester);
      expect(find.widgetWithText(ListTile, 'Artists'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Other'), findsOneWidget);
      expect(find.text('Cookie'), findsNothing);
      expect(find.text('Deep'), findsNothing);
      await enter(tester, 'Artists');
      expect(choices, isEmpty);
      expect(find.widgetWithText(ListTile, 'Cookie'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Other'), findsNothing);
      expect(find.text('Deep'), findsNothing);
      expect(find.text('Create folder'), findsNothing);
      await enter(tester, 'Cookie');
      await enter(tester, 'Deep');
      expect(choices, isEmpty);
      expect(find.byType(FolderBreadcrumbs), findsOneWidget);
      expect(find.text('Artists / Cookie / Deep'), findsNothing);
      await select(tester);
      expect(choices, [(id: deep, isNew: false)]);
      expect(
        find.descendant(
          of: find.byType(PinSearchFolderPicker),
          matching: find.text('Deep'),
        ),
        findsOneWidget,
      );
      await open(tester);
      expect(
        find.text('Deep'),
        findsNWidgets(2),
      ); // Selected field and breadcrumb.
      await tester.tap(find.widgetWithText(ListTile, 'Back'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Deep'), findsOneWidget);
      await select(tester);
      expect(choices.last, (id: child, isNew: false));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing starts in its saved folder and cancel preserves the destination',
    (tester) async {
      await initialize();
      await pump(tester, initial: child);
      await open(tester);
      expect(find.widgetWithText(ListTile, 'Deep'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(choices, isEmpty);
      await open(tester);
      expect(find.widgetWithText(ListTile, 'Deep'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Home'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Artists'), findsOneWidget);
      await select(tester);
      expect(choices.single, (id: null, isNew: false));
      expect(find.text('[Home]'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home remains selectable with no folders and New Folder keeps its existing result',
    (tester) async {
      await initialize();
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      for (final folder in [
        ...harness.container
            .read(searchSubscriptionsProvider)
            .requireValue
            .organization
            .folders
            .where((f) => f.parentId == null),
      ]) {
        await notifier.deleteSharedFolderAndPins(folder.id);
      }
      await pump(tester);
      await open(tester);
      expect(find.byType(ListTile), findsNothing);
      await select(tester);
      expect(choices.single, (id: null, isNew: false));
      await open(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Create folder'));
      await tester.pumpAndSettle();
      expect(choices.last, (id: null, isNew: true));
      expect(find.text('[New]'), findsOneWidget);
      expect(harness.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested selection fits narrow width and enlarged text after editing the name',
    (tester) async {
      await initialize();
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, scale: 2);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Cats');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      await enter(tester, 'Artists');
      await enter(tester, 'Cookie');
      await enter(tester, 'Deep');
      expect(
        find.widgetWithText(FilledButton, 'Select').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, 'Cancel').hitTestable(),
        findsOneWidget,
      );
      await select(tester);
      expect(choices.single, (id: deep, isNew: false));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Cats',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
