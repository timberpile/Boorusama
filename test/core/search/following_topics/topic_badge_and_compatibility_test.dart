import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/search_refresh_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  setUp(() => harness = FollowingTopicHarness());
  tearDown(() => harness.dispose());

  for (final item in [
    (
      count: 7,
      lowerBound: true,
      label: '7+',
      semantics: 'At least 7 new posts',
    ),
    (count: 7, lowerBound: false, label: '7', semantics: '7 new posts'),
    (count: 1, lowerBound: false, label: '1', semantics: '1 new post'),
    (
      count: null,
      lowerBound: false,
      label: 'NEW',
      semantics: 'New posts available',
    ),
  ]) {
    testWidgets(
      'new-post badge contains ${item.label} once and announces the count',
      (tester) async {
        final semantics = tester.ensureSemantics();

        try {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await harness.pump(
            tester,
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: FollowingTopicCard(
                    topic: topicFixture(
                      newPostCountEstimate: item.count,
                      newPostCountIsLowerBound: item.lowerBound,
                    ),
                    config: testProfile.auth,
                    refreshing: false,
                    onOpen: () {},
                    onAction: (_) {},
                  ),
                ),
              ),
            ),
          );
          expect(
            find.descendant(
              of: find.byType(Badge),
              matching: find.text(item.label),
            ),
            findsOneWidget,
          );
          expect(find.text(item.label), findsOneWidget);
          if (item.count != null) expect(find.text('NEW'), findsNothing);
          expect(
            find.bySemanticsLabel(RegExp(RegExp.escape(item.semantics))),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  test(
    'legacy settings retain topic sort, feed sort and disabled refresh scopes',
    () {
      final settings = Settings.fromJson({
        ...Settings.defaultSettings.toJson()
          ..remove('followingTopicSort')
          ..remove('topicFeedMemberSort'),
        'pinnedSearchSort': 'updatesFirst',
        'followingFeedMemberSort': 'oldestFirst',
        'searchRefresh': {
          'schemaVersion': 2,
          'pinnedSearchesEnabled': false,
          'followingFeedsEnabled': false,
        },
      });
      expect(settings.followingTopicSort, 'updatesFirst');
      expect(settings.topicFeedMemberSort, 'oldestFirst');
      expect(settings.searchRefresh.followingTopicsEnabled, isFalse);
      expect(settings.searchRefresh.topicFeedsEnabled, isFalse);
      expect(settings.toJson(), isNot(contains('pinnedSearchSort')));
      expect(
        settings.searchRefresh.toJson(),
        isNot(contains('pinnedSearchesEnabled')),
      );
    },
  );

  test('current settings take precedence over legacy aliases', () {
    final settings = Settings.fromJson({
      ...Settings.defaultSettings.toJson(),
      'followingTopicSort': 'nameAsc',
      'pinnedSearchSort': 'updatesFirst',
    });
    expect(settings.followingTopicSort, 'nameAsc');
    final refresh = SearchRefreshSettings.parse({
      'schemaVersion': 2,
      'followingTopicsEnabled': false,
      'pinnedSearchesEnabled': true,
    });
    expect(refresh.followingTopicsEnabled, isFalse);
  });
}
