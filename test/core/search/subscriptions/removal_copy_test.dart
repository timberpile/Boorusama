import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feeds_page.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  setUp(() => harness = PinnedSearchHarness());
  tearDown(() => harness.dispose());

  void constrain(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> selectAction(WidgetTester tester, String label) async {
    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('feed Delete cancels safely and confirms the original cleanup', (
    tester,
  ) async {
    constrain(tester);
    await tester.runAsync(() => harness.seed([pinnedFixture(query: 'cat')]));
    final feed = (await tester.runAsync(
      () => harness.repository.saveFeed(
        profileId: testProfile.id,
        name: 'Animals',
        queries: ['cat'],
      ),
    ))!;
    await tester.runAsync(
      () => harness.container.read(searchSubscriptionsProvider.future),
    );
    await harness.pump(tester, const FollowingFeedsPage());
    final before = await tester.runAsync(harness.repository.getAll);

    await selectAction(tester, 'Delete');
    expect(find.text('Delete this feed?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
    expect(find.textContaining('hidden searches'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(harness.repository.getAll), before);
    expect(
      (await tester.runAsync(harness.repository.getFeeds))!.single.id,
      feed.id,
    );

    await selectAction(tester, 'Delete');
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await drain(tester);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(harness.repository.getFeeds), isEmpty);
    expect(
      (await tester.runAsync(harness.repository.getAll))!.map((s) => s.id),
      ['cats'],
    );
    expect(find.text('Animals'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pin Remove keeps feed sources and folder Delete stays distinct',
    (
      tester,
    ) async {
      constrain(tester);
      await tester.runAsync(() => harness.seed([pinnedFixture(query: 'cat')]));
      final feed = (await tester.runAsync(
        () => harness.repository.saveFeed(
          profileId: testProfile.id,
          name: 'Animals',
          queries: ['cat'],
        ),
      ))!;
      await tester.runAsync(
        () => harness.container.read(searchSubscriptionsProvider.future),
      );
      final folder = (await tester.runAsync(
        () => harness.container
            .read(searchSubscriptionsProvider.notifier)
            .createSharedFolder('Favorites'),
      ))!;
      await harness.pump(tester, const PinnedSearchesPage());
      final before = await tester.runAsync(harness.repository.getAll);

      Future<void> remove() async {
        await tester.tap(
          find.descendant(
            of: find.byType(PinnedSearchCard),
            matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete'), findsNothing);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(find.text('Remove this pinned search?'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Remove'), findsOneWidget);
        expect(find.textContaining('cached previews'), findsNothing);
      }

      await remove();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(harness.repository.getAll), before);
      await remove();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => harness.repository.getById('cats')),
        isNull,
      );
      expect(
        (await tester.runAsync(harness.repository.getAll))!.map((s) => s.id),
        feed.sourceIds,
      );
      expect(
        (await tester.runAsync(harness.repository.getFeeds))!.single,
        feed,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('pinned-search-folder-${folder.id}')),
          matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Favorites"?'), findsOneWidget);
      expect(
        find.text(
          'This will permanently delete 1 folders and 0 pinned searches.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          harness.repository.getOrganization,
        ))!.folders.single.id,
        folder.id,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
