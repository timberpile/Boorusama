import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  setUp(() {
    harness = PinnedSearchHarness();
  });
  tearDown(() => harness.dispose());

  test(
    'moving and deleting folders preserves search checkpoints and manual order',
    () async {
      final cats = pinnedFixture(query: 'cat');
      final dogs = pinnedFixture(
        id: 'dogs',
        name: 'Dogs',
        query: 'dog',
        position: 1,
      );
      await harness.seed([cats, dogs]);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      await notifier.createFolder(12, 'Animals');
      final folder = harness.container
          .read(searchSubscriptionsProvider)
          .requireValue
          .folders
          .single;
      await notifier.moveToFolder(cats, folder.id);
      await notifier.moveToFolder(dogs, folder.id);
      await notifier.moveInGroup(dogs, -1, [cats, dogs]);
      final group = harness.container
          .read(
            folderPinnedSearchesProvider((profileId: 12, folderId: folder.id)),
          )
          .requireValue;
      expect(group.map((s) => s.id), ['dogs', 'cats']);
      expect(group.last.lastSuccessfulCheckAt, cats.lastSuccessfulCheckAt);
      await notifier.editFolder(folder, delete: true);
      final unfiled = harness.container
          .read(folderPinnedSearchesProvider((profileId: 12, folderId: null)))
          .requireValue;
      expect(unfiled.map((s) => s.id), ['dogs', 'cats']);
      expect(unfiled.last.hasNewPosts, isTrue);
    },
  );

  testWidgets(
    'creating a folder keeps text input alive until the dialog finishes closing',
    (tester) async {
      await harness.pump(tester, const PinnedSearchesPage());
      await tester.tap(find.byTooltip('Create folder'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Animals');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Animals'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening a folder navigates to its own manually ordered search page',
    (tester) async {
      await tester.runAsync(() async {
        final cats = pinnedFixture(query: 'cat');
        await harness.seed([cats]);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        await harness.container.read(searchSubscriptionsProvider.future);
        await notifier.createFolder(12, 'Animals');
        final folder = harness.container
            .read(searchSubscriptionsProvider)
            .requireValue
            .folders
            .single;
        await notifier.moveToFolder(cats, folder.id);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text('Cats'), findsNothing);
      expect(find.text('Animals'), findsOneWidget);
      await tester.tap(find.text('Animals'));
      await settle(tester);
      expect(find.text('Cats'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(harness.requests, isEmpty);
    },
  );
}
