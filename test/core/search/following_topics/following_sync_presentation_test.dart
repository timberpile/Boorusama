import 'package:boorusama/core/backups/mitemite/mitemite_icon.dart';
import 'package:boorusama/core/backups/mitemite/providers.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_folder_card.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/topic_new_posts_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';

final roots = StateProvider<Set<String>>((ref) => {});

void main() {
  testWidgets(
    'only explicit folder roots show MiteMite; Topic menu never publishes',
    (tester) async {
      final harness = FollowingTopicHarness(
        overrides: [
          publishedFollowingRootsProvider.overrideWith(
            (ref) => ref.watch(roots),
          ),
        ],
      );
      addTearDown(harness.dispose);
      await harness.seed([topicFixture()]);
      final notifier = harness.container.read(followingTopicsProvider.notifier);
      final parent = await notifier.createSharedFolder(
        'Published parent',
        feedEnabled: true,
      );
      final child = await notifier.createSharedFolder(
        'Covered child',
        parentId: parent.id,
        feedEnabled: true,
      );
      await notifier.moveTopicToSharedFolder('cats', child.id);
      harness.container.read(roots.notifier).state = {parent.id};
      await harness.pump(tester, const FollowingTopicsPage());
      await settle(tester);
      expect(
        tester
            .widget<FollowingTopicFolderCard>(
              find.byType(FollowingTopicFolderCard),
            )
            .published,
        isTrue,
      );
      expect(find.byType(MiteMiteIcon), findsOneWidget);
      await tester.tap(find.text('Published parent'));
      await settle(tester);
      expect(
        tester
            .widget<FollowingTopicFolderCard>(
              find.byType(FollowingTopicFolderCard),
            )
            .published,
        isFalse,
      );
      expect(find.byType(MiteMiteIcon), findsNothing);
      harness.container.read(roots.notifier).state = {parent.id, child.id};
      await settle(tester);
      expect(
        tester
            .widget<FollowingTopicFolderCard>(
              find.byType(FollowingTopicFolderCard),
            )
            .published,
        isTrue,
      );
      await tester.tap(find.text('Covered child'));
      await settle(tester);
      final card = find.byType(FollowingTopicCard);
      expect(tester.widget<FollowingTopicCard>(card).published, isFalse);
      expect(
        find.descendant(of: card, matching: find.byType(MiteMiteIcon)),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: card, matching: find.byType(KurumiPopupMenuButton)),
      );
      await settle(tester);
      final t = tester.element(card).t.mitemite;
      expect(find.text(t.publish), findsNothing);
      expect(find.text(t.manage_publication), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'UNSEEN and Post NEW remain independent at 320dp and text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final harness = FollowingTopicHarness();
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          Scaffold(
            body: FollowingTopicCard(
              topic: topicFixture(
                name: 'Received Topic',
                unreadCount: 1,
                newPostCountEstimate: 3,
              ),
              config: null,
              refreshing: false,
              onOpen: null,
              onAction: (_) {},
              readOnly: true,
              definitionChanged: true,
            ),
          ),
        );
        await settle(tester);
        expect(find.text('UNSEEN'), findsOneWidget);
        expect(find.byType(TopicNewPostsBadge), findsOneWidget);
        final unseen = tester.widget<Badge>(
          find.ancestor(of: find.text('UNSEEN'), matching: find.byType(Badge)),
        );
        expect(unseen.backgroundColor, Colors.blue.shade700);
        expect(find.byTooltip('Definition Updated'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
