import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() => harness = FollowingTopicHarness());
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
    await tester.runAsync(() => harness.seed([topicFixture(query: 'cat')]));
    final feed = (await tester.runAsync(
      () => harness.repository.saveFeed(
        profileId: testProfile.id,
        name: 'Animals',
        queries: ['cat'],
      ),
    ))!;
    await tester.runAsync(
      () => harness.container.read(followingTopicsProvider.future),
    );
    await harness.pump(tester, const TopicFeedsPage());
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
    'topic Remove keeps feed sources and folder Delete stays distinct',
    (
      tester,
    ) async {
      constrain(tester);
      await tester.runAsync(() => harness.seed([topicFixture(query: 'cat')]));
      final feed = (await tester.runAsync(
        () => harness.repository.saveFeed(
          profileId: testProfile.id,
          name: 'Animals',
          queries: ['cat'],
        ),
      ))!;
      await tester.runAsync(
        () => harness.container.read(followingTopicsProvider.future),
      );
      final folder = (await tester.runAsync(
        () => harness.container
            .read(followingTopicsProvider.notifier)
            .createSharedFolder('Favorites'),
      ))!;
      await harness.pump(tester, const FollowingTopicsPage());
      await drain(tester);
      final before = await tester.runAsync(harness.repository.getAll);

      Future<void> remove() async {
        await tester.tap(
          find.descendant(
            of: find.byType(FollowingTopicCard),
            matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete'), findsNothing);
        await tester.tap(find.text('Unfollow'));
        await tester.pumpAndSettle();
        expect(find.text('Unfollow this topic?'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Unfollow'), findsOneWidget);
        expect(find.textContaining('cached previews'), findsNothing);
      }

      await remove();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(harness.repository.getAll), before);
      await remove();
      await tester.tap(find.widgetWithText(FilledButton, 'Unfollow'));
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
      final retainedFeed = (await tester.runAsync(
        harness.repository.getFeeds,
      ))!.single;
      expect(retainedFeed.id, feed.id);
      expect(retainedFeed.sourceIds, feed.sourceIds);

      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('following-topic-folder-${folder.id}')),
          matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Favorites"?'), findsOneWidget);
      expect(
        find.text(
          'This will permanently delete 1 folders and 0 topics.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          harness.repository.getOrganization,
        ))!.folders.where((item) => item.id == folder.id).single.id,
        folder.id,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
