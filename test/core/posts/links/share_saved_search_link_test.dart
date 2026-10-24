import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feed_management_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final inFeed in [false, true]) {
    testWidgets(
      'Following Topic menu omits Boorusama Link File: feed=$inFeed',
      (tester) async {
        final owner = BooruConfig.fromJson({
          ...otherTestProfile.toJson(),
          'booruId': 1,
          'booruIdHint': 1,
          'name': 'Personal Danbooru',
        });
        late FollowingTopicHarness h;
        h = FollowingTopicHarness(profiles: [testProfile, owner]);
        addTearDown(h.dispose);
        String? feedId;
        var sourceId = 'cats';
        if (inFeed) {
          final feed = await h.repository.saveFeed(
            profileId: owner.id,
            name: 'Artists',
            queries: ['cat -dog'],
          );
          feedId = feed.id;
          sourceId = feed.sourceIds.single;
        }
        await h.seed([
          topicFixture(id: sourceId, profileId: owner.id, query: 'cat -dog'),
        ]);
        await h.pump(
          tester,
          inFeed
              ? TopicFeedManagementPage(feedId: feedId!)
              : const FollowingTopicsPage(),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(FollowingTopicCard).first,
            matching: find.byType(PopupMenuButton<FollowingTopicAction>),
          ),
        );
        await settle(tester);
        expect(find.text('Refresh'), findsOneWidget);
        expect(find.text('Boorusama Link File'), findsNothing);
        expect(h.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
