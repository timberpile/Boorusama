import 'package:boorusama/core/posts/post/types.dart';

import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topics_notifier.dart';
import 'package:boorusama/core/search/following_topics/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import 'following_topic_test_utils.dart';
import 'search_refresh_lifecycle_test.dart' show drainRefresh;

final _enabled = StateProvider((ref) => true);

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

FollowingTopic copy() => FollowingTopic.create(
  id: '11111111-1111-4111-8111-111111111111',
  profileId: '11111111-1111-4111-8111-111111111111',
  query: 'cat',
  name: 'Copied cats',
  position: 0,
  createdAt: checkedAt,
  localSource: FollowingTopicSource(
    booruType: 'danbooru',
    url: 'https://safebooru.donmai.us',
  ),
);
List<Override> overrides() => [
  globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
  anonymousSourcePolicyProvider.overrideWith(
    (ref) => AnonymousSourcePolicy(enabled: ref.watch(_enabled)),
  ),
];

void main() {
  testWidgets(
    'public independent copy stays searchable, refreshable and editable with zero profiles at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = FollowingTopicHarness(
        profiles: [],
        overrides: overrides(),
      );
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([copy()]);
        await harness.container.read(followingTopicsProvider.future);
      });
      await harness.pump(tester, const FollowingTopicsPage());
      expect(find.text('Copied cats'), findsOneWidget);
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Copied');
      await settle(tester);
      expect(find.text('Copied cats'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      tester.testTextInput.hide();
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Refresh All'));
      await drain(tester);
      await settle(tester);
      expect(harness.requests.map((r) => r.query), ['cat']);
      final card = find.byType(FollowingTopicCard);
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.bySemanticsLabel(RegExp(r'^(More|Mehr)$')),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Independent cats');
      tester.testTextInput.hide();

      await tester.tap(find.text('Save'));
      await drain(tester);

      expect(find.text('Independent cats'), findsOneWidget);
      expect(harness.container.read(booruConfigProvider), isEmpty);
      final saved = (await tester.runAsync(() => harness.repository.getAll()))!
          .single;
      expect(saved.localSource, copy().localSource);
      expect(tester.takeException(), isNull);
    },
  );

  for (final revoke in [false, true]) {
    testWidgets(
      'automatic public copy refresh ${revoke ? 'discards a revoked in-flight request' : 'runs without a saved profile'}',
      (tester) async {
        final entered = Completer<void>();
        final gate = Completer<void>();
        final configs = <BooruConfig>[];
        final harness = FollowingTopicHarness(
          profiles: [],
          overrides: overrides(),
          networkAllowed: true,
          clock: Clock.fixed(checkedAt.add(const Duration(days: 2))),
          beforeDispatch: () async {
            if (!entered.isCompleted) entered.complete();
          },
          fetchPosts: (config, _, _, _) async {
            configs.add(config);
            if (revoke) await gate.future;
            return Either.of(const PostResult(posts: [], total: 0));
          },
        );
        addTearDown(harness.dispose);
        await tester.runAsync(() async {
          await harness.seed([copy()]);
          await harness.container.read(followingTopicsProvider.future);
        });
        final coordinator = harness.container.read(
          searchRefreshCoordinatorProvider.notifier,
        );
        coordinator.setForeground(true);
        await drainRefresh(tester);
        expect(entered.isCompleted, isTrue);
        expect(configs.single.anonymousReadScope?.isCurrent, isTrue);
        if (revoke) {
          harness.container.read(_enabled.notifier).state = false;
          expect(configs.single.anonymousReadScope?.isCurrent, isFalse);
          gate.complete();
          await drainRefresh(tester);
        }
        final saved = (await tester.runAsync(
          () => harness.repository.getAll(),
        ))!.single;
        expect(saved.lastSuccessfulCheckAt, revoke ? isNull : isNotNull);
        expect(saved.localSource, copy().localSource);
        coordinator.setForeground(false);
        await tester.pump(Duration.zero);
        expect(harness.container.read(booruConfigProvider), isEmpty);
      },
    );
  }
}
