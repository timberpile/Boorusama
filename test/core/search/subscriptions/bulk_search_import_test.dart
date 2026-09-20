import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/following_feed_management_page.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  setUp(() => harness = PinnedSearchHarness());
  tearDown(() => harness.dispose());

  test(
    'pasting searches into a selected folder creates independent pins once',
    () async {
      await harness.seed([pinnedFixture(query: 'cat')]);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      final folder = await notifier.createSharedFolder('Artists');

      final added = await notifier.bulkPinToFolder(
        profileId: 12,
        folderId: folder.id,
        rawQueries: ' dog  \n\ncat\ndog\n bird rating:safe \r\n',
      );

      expect(added, 2);
      final pins = await harness.repository.getAll();
      expect(pins.map((pin) => pin.query).toSet(), {
        'cat',
        'dog',
        'bird rating:safe',
      });
      final organization = await harness.repository.getOrganization();
      final placed = organization.folders.singleWhere((f) => f.id == folder.id);
      expect(placed.searchIds.length, 2);
      expect(placed.searchIds, isNot(contains('cats')));
      expect(harness.requests, isEmpty);
    },
  );

  test(
    'pasting into one feed preserves its existing source and other feeds',
    () async {
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      final first = await notifier.saveFeed(
        profileId: 12,
        name: 'First',
        queries: ['cat'],
      );
      final second = await notifier.saveFeed(
        profileId: 12,
        name: 'Second',
        queries: ['cat'],
      );

      final added = await notifier.bulkAddToFeed(
        feedId: first.id,
        rawQueries: ' dog \ncat\ndog\nbird rating:safe\n',
      );

      expect(added, 2);
      final feeds = await harness.repository.getFeeds();
      final updated = feeds.singleWhere((feed) => feed.id == first.id);
      expect(updated.sourceIds.length, 3);
      expect(feeds.singleWhere((feed) => feed.id == second.id).sourceIds, [
        second.sourceIds.single,
      ]);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('bulk entry adds searches to the opened folder', (tester) async {
    late String folderId;
    await tester.runAsync(() async {
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      folderId = (await notifier.createSharedFolder('Artists')).id;
    });
    await harness.pump(tester, PinnedSearchesPage(folderId: folderId));

    await tester.tap(find.byTooltip('Add searches'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'cat\ndog');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add searches'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add searches'));
    await tester.pumpAndSettle();
    await drain(tester);

    final organization = await tester.runAsync(
      () => harness.repository.getOrganization(),
    );
    expect(organization!.folders.single.searchIds.length, 2);
    expect(harness.requests, isEmpty);
  });

  testWidgets('bulk entry adds searches to the opened feed', (tester) async {
    late String feedId;
    await tester.runAsync(() async {
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);
      feedId = (await notifier.saveFeed(
        profileId: 12,
        name: 'Artists',
        queries: ['cat'],
      )).id;
    });
    await harness.pump(tester, FollowingFeedManagementPage(feedId: feedId));

    await tester.tap(find.byTooltip('Add searches'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'dog\nbird');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add searches'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add searches'));
    await tester.pumpAndSettle();
    await drain(tester);

    final feeds = await tester.runAsync(() => harness.repository.getFeeds());
    expect(feeds!.single.sourceIds.length, 3);
    expect(harness.requests, isEmpty);
  });
}
