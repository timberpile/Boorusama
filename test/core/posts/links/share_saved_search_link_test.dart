import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/posts/links/share_search_link_button.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feed_management_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final inFeed in [false, true]) {
    testWidgets(
      'file sharing preserves the owner and read state: feed=$inFeed',
      (tester) async {
        final owner = BooruConfig.fromJson({
          ...otherTestProfile.toJson(),
          'booruId': 1,
          'booruIdHint': 1,
          'name': 'Personal Danbooru',
        });
        late FollowingTopicHarness h;
        final shared = <BoorusamaLinkFile>[];
        final messages = <String?>[];
        h = FollowingTopicHarness(
          profiles: [testProfile, owner],
          overrides: [
            searchLinkShareAdapterProvider.overrideWithValue(
              ShareActionAdapter((params) async {
                expect(params.files, hasLength(1));
                expect(params.uri, isNull);
                final file = params.files!.single;
                expect(file.mimeType, BoorusamaLinkFile.mimeType);
                final fs = h.container.read(appFileSystemProvider);
                shared.add(
                  BoorusamaLinkFile.decode(await fs.readBytes(file.path)),
                );
                messages.add(params.text);
                return const ShareResult('', ShareResultStatus.success);
              }),
            ),
          ],
        );
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
        final before = await h.repository.getById(sourceId);
        final feedsBefore = await h.repository.getFeeds();
        await tester.tap(
          find.descendant(
            of: find.byType(FollowingTopicCard).first,
            matching: find.byType(PopupMenuButton<FollowingTopicAction>),
          ),
        );
        await settle(tester);
        expect(find.text('Copy Boorusama search link'), findsNothing);
        expect(find.text('Share Boorusama search link'), findsNothing);
        expect(find.text('Boorusama Link File'), findsOneWidget);
        await tester.tap(find.text('Boorusama Link File'));
        await settle(tester);
        await drain(tester);
        expect(shared, hasLength(1));
        final link = BoorusamaSearchLink.parse(shared.single.uri.toString());
        expect(link.site.toString(), owner.url);
        expect(link.query, before!.query);
        expect(link.isRaw, isTrue);
        expect(messages.single, "Search 'cat -dog' on Personal Danbooru");
        expect(await h.repository.getById(sourceId), before);
        expect(await h.repository.getFeeds(), feedsBefore);
        expect(
          h.container.read(selectedTestProfileProvider).id,
          testProfile.id,
        );
        expect(h.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
