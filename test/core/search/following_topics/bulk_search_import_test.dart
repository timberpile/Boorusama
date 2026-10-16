import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feed_management_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() => harness = FollowingTopicHarness());
  tearDown(() => harness.dispose());

  test(
    'pasting searches into a selected folder creates independent topics once',
    () async {
      await harness.seed([topicFixture(query: 'cat')]);
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);
      final folder = await notifier.createSharedFolder('Artists');

      final added = await notifier.bulkFollowToFolder(
        profileId: '00000000-0000-4000-8000-00000000000c',
        folderId: folder.id,
        rawQueries: ' dog  \n\ncat\ndog\n bird rating:safe \r\n',
      );

      expect(added, 3);
      final topics = await harness.repository.getAll();
      expect(topics.map((topic) => topic.query).toSet(), {
        'cat',
        'dog',
        'bird rating:safe',
      });
      final organization = await harness.repository.getOrganization();
      final placed = organization.folders.singleWhere((f) => f.id == folder.id);
      expect(placed.searchIds.length, 3);
      expect(placed.searchIds, isNot(contains('cats')));
      expect(harness.requests, isEmpty);
    },
  );

  test(
    'pasting into one feed preserves its existing source and other feeds',
    () async {
      final notifier = harness.container.read(
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);
      final first = await notifier.saveFeed(
        profileId: '00000000-0000-4000-8000-00000000000c',
        name: 'First',
        queries: ['cat'],
      );
      final second = await notifier.saveFeed(
        profileId: '00000000-0000-4000-8000-00000000000c',
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
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);
      folderId = (await notifier.createSharedFolder('Artists')).id;
    });
    await harness.pump(tester, FollowingTopicsPage(folderId: folderId));

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('More'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Follow Topics'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'cat\ndog');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Follow Topics'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Follow Topics'));
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
        followingTopicsProvider.notifier,
      );
      await harness.container.read(followingTopicsProvider.future);
      feedId = (await notifier.saveFeed(
        profileId: '00000000-0000-4000-8000-00000000000c',
        name: 'Artists',
        queries: ['cat'],
      )).id;
    });
    await harness.pump(tester, TopicFeedManagementPage(feedId: feedId));

    await tester.tap(find.byTooltip('Follow Topics'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'dog\nbird');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Follow Topics'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Follow Topics'));
    await tester.pumpAndSettle();
    await drain(tester);

    final feeds = await tester.runAsync(() => harness.repository.getFeeds());
    expect(feeds!.single.sourceIds.length, 3);
    expect(harness.requests, isEmpty);
  });
}
