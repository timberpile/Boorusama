import 'package:boorusama/core/groups/folder_navigation.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/follow_topic_dialog.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/follow_topic_folder_picker.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/search_folder_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  late String root;
  late String child;
  late String deep;
  final choices = <({String? id, SearchFolderSettings? newFolder})>[];

  Future<void> initialize() async {
    choices.clear();
    harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    await harness.seed([]);
    final notifier = harness.container.read(
      followingTopicsProvider.notifier,
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
            body: FollowTopicDialog(
              query: 'cat',
              isFollowing: initial != null,
              extra: FollowTopicFolderPicker(
                initialFolderId: initial,
                onSelected: (id, newFolder) =>
                    choices.add((id: id, newFolder: newFolder)),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FollowTopicFolderPicker));
    await tester.tap(find.byType(FollowTopicFolderPicker));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(legacy.ListTile, name));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(legacy.FilledButton, 'Select'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows only direct folders and confirms a deeply nested destination',
    (tester) async {
      await initialize();
      await pump(tester);
      await open(tester);
      expect(find.widgetWithText(legacy.ListTile, 'Artists'), findsOneWidget);
      expect(find.widgetWithText(legacy.ListTile, 'Other'), findsOneWidget);
      expect(find.text('Cookie'), findsNothing);
      expect(find.text('Deep'), findsNothing);
      await enter(tester, 'Artists');
      expect(choices, isEmpty);
      expect(find.widgetWithText(legacy.ListTile, 'Cookie'), findsOneWidget);
      expect(find.widgetWithText(legacy.ListTile, 'Other'), findsNothing);
      expect(find.text('Deep'), findsNothing);
      expect(find.text('Create folder'), findsOneWidget);
      await enter(tester, 'Cookie');
      await enter(tester, 'Deep');
      expect(choices, isEmpty);
      expect(find.byType(FolderBreadcrumbs), findsOneWidget);
      expect(find.text('Artists / Cookie / Deep'), findsNothing);
      await select(tester);
      expect(choices, [(id: deep, newFolder: null)]);
      expect(
        find.descendant(
          of: find.byType(FollowTopicFolderPicker),
          matching: find.text('Artists / Cookie / Deep'),
        ),
        findsOneWidget,
      );
      await open(tester);
      expect(
        find.text('Deep'),
        findsOneWidget,
      ); // Breadcrumb; field shows path.
      await tester.tap(find.widgetWithText(legacy.ListTile, 'Back'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(legacy.ListTile, 'Deep'), findsOneWidget);
      await select(tester);
      expect(choices.last, (id: child, newFolder: null));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing starts in its saved folder and cancel preserves the destination',
    (tester) async {
      await initialize();
      await pump(tester, initial: child);
      await open(tester);
      expect(find.widgetWithText(legacy.ListTile, 'Deep'), findsOneWidget);
      await tester.tap(find.widgetWithText(legacy.TextButton, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(legacy.TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(choices, isEmpty);
      await open(tester);
      expect(find.widgetWithText(legacy.ListTile, 'Deep'), findsOneWidget);
      await tester.tap(find.widgetWithText(legacy.TextButton, 'Home'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(legacy.ListTile, 'Artists'), findsOneWidget);
      await select(tester);
      expect(choices.single, (id: null, newFolder: null));
      expect(find.text('No folder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'No folder remains selectable and a nested new-folder draft is returned',
    (tester) async {
      await initialize();
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      for (final folder in [
        ...harness.container
            .read(followingTopicsProvider)
            .requireValue
            .organization
            .folders
            .where((f) => f.parentId == null),
      ]) {
        await notifier.deleteSharedFolderAndTopics(folder.id);
      }
      await pump(tester);
      await open(tester);
      expect(find.byType(legacy.ListTile), findsNothing);
      await select(tester);
      expect(choices.single, (id: null, newFolder: null));
      await open(tester);
      await tester.tap(
        find.widgetWithText(legacy.TextButton, 'Create folder'),
      );
      await tester.pumpAndSettle();
      expect(choices.last.id, isNull);
      expect(choices.last.newFolder?.name, isEmpty);
      expect(choices.last.newFolder?.parentId, isNull);
      expect(choices.last.newFolder?.feedEnabled, isFalse);
      expect(find.text('New folder'), findsOneWidget);
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
        find.widgetWithText(legacy.FilledButton, 'Select').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(legacy.TextButton, 'Cancel').hitTestable(),
        findsOneWidget,
      );
      await select(tester);
      expect(choices.single, (id: deep, newFolder: null));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Cats',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
