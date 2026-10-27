import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_folder_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() => harness = FollowingTopicHarness());
  tearDown(() => harness.dispose());

  Finder folder(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(FollowingTopicFolderCard),
  );

  for (final empty in [false, true]) {
    testWidgets(
      'folder feed shortcut opens ${empty ? 'empty' : 'populated'} enabled folder directly at 320px and 2x text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.runAsync(() async {
          if (!empty) await harness.seed([topicFixture(unreadCount: 0)]);
          await harness.repository.replaceOrganization(
            TopicOrganization(
              folders: [
                TopicFolder(
                  id: 'enabled',
                  name: 'Enabled folder',
                  feedEnabled: true,
                  searchIds: [if (!empty) 'cats'],
                ),
                TopicFolder(id: 'disabled', name: 'Disabled folder'),
              ],
            ),
          );
          await harness.container.read(followingTopicsProvider.future);
        });
        await harness.pump(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: const FollowingTopicsPage(),
            ),
          ),
        );
        expect(find.text('Following Topics'), findsOneWidget);
        final feedButton = find.descendant(
          of: folder('Enabled folder'),
          matching: find.byTooltip('Open Feed'),
        );
        final overflow = find.descendant(
          of: folder('Enabled folder'),
          matching: find.byType(PopupMenuButton<FollowingTopicAction>),
        );
        expect(feedButton, findsOneWidget);
        expect(
          find.descendant(
            of: folder('Disabled folder'),
            matching: find.byTooltip('Open Feed'),
          ),
          findsNothing,
        );
        expect(
          tester.getRect(feedButton).right,
          lessThanOrEqualTo(tester.getRect(overflow).left),
        );
        await tester.tap(feedButton);
        await drain(tester);
        await tester.pumpAndSettle();
        expect(find.byType(TopicFeedPage), findsOneWidget);
        expect(find.text('Enabled folder'), findsOneWidget);
        expect(
          (await tester.runAsync(harness.repository.getFeeds))!.single.id,
          'enabled',
        );
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Selection mode keeps the feed shortcut from interfering with bulk actions.
        await tester.longPress(folder('Enabled folder'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: folder('Enabled folder'),
            matching: find.byTooltip('Open Feed'),
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'alphabetical view orders topics and child folders and preserves manual order',
    (tester) async {
      await tester.runAsync(() async {
        await harness.seed([
          topicFixture(
            id: 'z',
            name: 'Zebra',
            query: 'zebra',
            position: 0,
            unreadCount: 0,
          ),
          topicFixture(
            id: 'a',
            name: 'apple',
            query: 'apple',
            position: 1,
            unreadCount: 0,
          ),
        ]);
        await harness.repository.replaceOrganization(
          TopicOrganization(
            folders: [
              TopicFolder(id: 'root', name: 'Root', searchIds: ['z', 'a']),
              TopicFolder(id: 'child-z', name: 'Z child', parentId: 'root'),
              TopicFolder(
                id: 'child-a',
                name: 'a child',
                parentId: 'root',
                position: 1,
              ),
            ],
          ),
        );
      });
      await tester.runAsync(
        () => harness.container.read(followingTopicsProvider.future),
      );
      await harness.pump(tester, const FollowingTopicsPage(folderId: 'root'));
      await drain(tester);
      expect(
        tester.getTopLeft(find.text('Zebra')).dy,
        lessThan(tester.getTopLeft(find.text('apple')).dy),
      );
      await tester.tap(find.byTooltip('Sort By'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name (A-Z)'));
      await drain(tester);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('apple')).dy,
        lessThan(tester.getTopLeft(find.text('Zebra')).dy),
      );
      expect(
        tester.getTopLeft(find.text('a child')).dy,
        lessThan(tester.getTopLeft(find.text('Z child')).dy),
      );
      expect(
        (await tester.runAsync(
          harness.repository.getOrganization,
        ))!.folders.singleWhere((f) => f.id == 'root').searchIds,
        ['z', 'a'],
      );
    },
  );
}
