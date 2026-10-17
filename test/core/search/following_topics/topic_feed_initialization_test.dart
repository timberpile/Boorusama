import 'dart:async';

import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/pages/topic_feeds_page.dart';
import 'package:boorusama/core/search/following_topics/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_environment.dart';
import 'package:boorusama/core/search/following_topics/src/services/conservative_refresh_policy.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/search_refresh_lifecycle.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/feed_last_checked.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';

import 'following_topic_test_utils.dart';
import 'topic_test_utils.dart';

void main() {
  FollowingTopicHarness createHarness({
    bool networkAllowed = true,
    Duration spacing = Duration.zero,
    SearchRefreshEnvironment Function(bool networkAllowed)? refreshEnvironment,
    Future<Either<BooruError, PostResult<Post>>> Function(
      String query,
      int page,
      int? limit,
    )?
    fetch,
  }) => FollowingTopicHarness(
    networkAllowed: networkAllowed,
    refreshEnvironment: refreshEnvironment,
    settings: Settings.defaultSettings.copyWith(
      searchRefresh: Settings.defaultSettings.searchRefresh.copyWith(
        enabled: false,
      ),
    ),
    clock: Clock.fixed(checkedAt),
    scheduler: SearchRefreshScheduler(
      clock: Clock.fixed(checkedAt),
      maxChecks: 3,
      spacing: spacing,
    ),
    fetchPosts: fetch == null
        ? null
        : (config, query, page, limit) => fetch(query, page, limit),
  );

  for (final unknownPower in [false, true]) {
    testWidgets(
      'initialization waits for power guards (unknown: $unknownPower)',
      (tester) async {
        var environment = SearchRefreshEnvironment(
          network: RefreshNetwork.wifi,
          powerKnown: !unknownPower,
          batterySaver: !unknownPower,
        );
        final harness = createHarness(refreshEnvironment: (_) => environment);
        addTearDown(harness.dispose);
        await seedFeeds(
          tester,
          harness,
          [topicFixture(id: 'a', query: 'a', checked: false)],
          [
            TopicFeed(
              id: 'feed',
              profileId: testProfile.id,
              name: 'Feed',
              sourceIds: ['a'],
            ),
          ],
        );
        await pumpOverview(harness, tester);
        await drain(tester);
        expect(harness.requests, isEmpty);
        environment = const SearchRefreshEnvironment(
          network: RefreshNetwork.wifi,
          powerKnown: true,
        );
        harness.container.invalidate(searchRefreshEnvironmentProvider);
        await drain(tester);
        expect(harness.requests.map((request) => request.query), ['a']);
      },
    );
  }

  testWidgets(
    'overview initializes uncached members across profiles including previously checked topics',
    (tester) async {
      final calls = <({String query, int page, int? limit})>[];
      final harness = createHarness(
        fetch: (query, page, limit) async {
          calls.add((query: query, page: page, limit: limit));
          return Either.of(const PostResult(posts: <Post>[], total: 0));
        },
      );
      addTearDown(harness.dispose);
      final members = [
        for (var i = 0; i < 14; i++)
          topicFixture(
            id: 'source-${i.toString().padLeft(2, '0')}',
            profileId: i < 7
                ? '00000000-0000-4000-8000-00000000000c'
                : '00000000-0000-4000-8000-000000000063',
            query: 'artist_$i',
            checked: false,
            unreadCount: 0,
          ),
      ];
      final checked = topicFixture(id: 'checked-empty', query: 'checked');
      final attempted = topicFixture(
        id: 'failed-empty',
        query: 'failed',
        checked: false,
        error: SearchRefreshErrorKind.rateLimited,
      );
      await seedFeeds(
        tester,
        harness,
        [
          ...members,
          checked,
          attempted,
          topicFixture(id: 'independent', query: 'topic', checked: false),
        ],
        [
          TopicFeed(
            id: 'first',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'First',
            sourceIds: [
              ...members.take(7).map((s) => s.id),
              checked.id,
              attempted.id,
            ],
          ),
          TopicFeed(
            id: 'shared',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'Shared',
            sourceIds: [members.first.id],
          ),
          TopicFeed(
            id: 'other',
            profileId: '00000000-0000-4000-8000-000000000063',
            name: 'Other',
            sourceIds: members.skip(7).map((s) => s.id).toList(),
          ),
        ],
      );

      await pumpOverview(harness, tester);
      await drain(tester);

      expect(calls.map((c) => c.query), [
        'failed',
        ...members.map((s) => s.query),
        'checked',
      ]);
      expect(calls.every((c) => c.page == 1 && c.limit == 50), isTrue);
      expect(harness.requests.map((r) => r.profileId), [
        ...List.filled(8, '00000000-0000-4000-8000-00000000000c'),
        ...List.filled(7, '00000000-0000-4000-8000-000000000063'),
        '00000000-0000-4000-8000-00000000000c',
      ]);
      for (final member in members) {
        expect(
          (await tester.runAsync(
            () => harness.repository.getById(member.id),
          ))!.lastSuccessfulCheckAt,
          checkedAt,
        );
      }

      await harness.pump(tester, const SizedBox.shrink());
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(calls.length, 16);
    },
  );

  testWidgets(
    'rebuild and reopen while a first check is pending do not duplicate requests',
    (tester) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      harness.refreshGate = Completer<void>();
      final sources = [
        for (final id in ['a', 'a', 'b'])
          topicFixture(id: id, query: id, checked: false),
      ];
      await seedFeeds(tester, harness, sources, [
        TopicFeed(
          id: 'feed',
          profileId: '00000000-0000-4000-8000-00000000000c',
          name: 'Feed',
          sourceIds: const ['a', 'a', 'b'],
        ),
      ]);
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a']);
      await pumpOverview(harness, tester, key: const ValueKey('rebuilt'));
      await harness.pump(tester, const SizedBox.shrink());
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a']);
      harness.refreshGate!.complete();
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a', 'a', 'b']);
    },
  );

  testWidgets(
    'a failed first check does not starve later entries or retry after provider recreation',
    (tester) async {
      final harness = createHarness(
        fetch: (query, page, limit) async => query == 'a'
            ? Either.left(
                ServerError(httpStatusCode: 429, message: 'rate limited'),
              )
            : Either.of(const PostResult(posts: <Post>[], total: 0)),
      );
      addTearDown(harness.dispose);
      await seedFeeds(
        tester,
        harness,
        [
          for (final id in ['a', 'b', 'c', 'd'])
            topicFixture(id: id, query: id, checked: false),
        ],
        [
          TopicFeed(
            id: 'feed',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'Feed',
            sourceIds: const ['a', 'b', 'c', 'd'],
          ),
        ],
      );
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a', 'b', 'c', 'd']);
      final failed = (await tester.runAsync(
        () => harness.repository.getById('a'),
      ))!;
      expect(failed.lastAttemptAt, checkedAt);
      expect(failed.lastSuccessfulCheckAt, isNull);
      expect(failed.lastErrorKind, SearchRefreshErrorKind.rateLimited);
      await harness.pump(tester, const SizedBox.shrink());
      harness.container.invalidate(searchRefreshCoordinatorProvider);
      harness.container.invalidate(followingTopicsProvider);
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.length, 4);
    },
  );

  testWidgets(
    'opening offline defers first checks until network policy permits them',
    (tester) async {
      final harness = createHarness(networkAllowed: false);
      addTearDown(harness.dispose);
      await seedFeeds(
        tester,
        harness,
        [topicFixture(id: 'a', query: 'a', checked: false)],
        [
          TopicFeed(
            id: 'feed',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'Feed',
            sourceIds: const ['a'],
          ),
        ],
      );
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests, isEmpty);
      harness.container
          .read(testRefreshNetworkAllowedProvider.notifier)
          .setAllowed(true);
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a']);
    },
  );

  testWidgets(
    'a newly added member is initialized on reopen without refreshing existing members',
    (tester) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      await seedFeeds(
        tester,
        harness,
        [topicFixture(id: 'a', query: 'a', checked: false)],
        [
          TopicFeed(
            id: 'feed',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'Feed',
            sourceIds: const ['a'],
          ),
        ],
      );
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a']);
      await harness.pump(tester, const SizedBox.shrink());
      final addition = harness.container
          .read(followingTopicsProvider.notifier)
          .setFeedFollowing(
            feedId: 'feed',
            profileId: '00000000-0000-4000-8000-00000000000c',
            query: 'b',
            following: true,
          );
      await drain(tester);
      await addition;
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.query), ['a', 'b']);
    },
  );

  testWidgets('first checks populate an empty feed from each member', (
    tester,
  ) async {
    final harness = createHarness(
      fetch: (query, _, _) async => Either.of(
        PostResult(
          posts: [testSearchPost(query == 'a' ? 1 : 2, checkedAt)],
          total: 1,
        ),
      ),
    );
    addTearDown(harness.dispose);
    await seedFeeds(
      tester,
      harness,
      [
        for (final id in ['a', 'b'])
          topicFixture(id: id, query: id, checked: false),
      ],
      [
        TopicFeed(
          id: 'feed',
          profileId: '00000000-0000-4000-8000-00000000000c',
          name: 'Feed',
          sourceIds: const ['a', 'b'],
        ),
      ],
    );
    await pumpOverview(harness, tester);
    await drain(tester);
    final feed = (await tester.runAsync(
      () => harness.repository.getFeeds(),
    ))!.single;
    expect(feed.posts.map(feedPostId).toSet(), {1, 2});
  });

  testWidgets(
    'pausing during initialization stops later requests until foreground resumes',
    (tester) async {
      final harness = createHarness(
        fetch: (query, _, _) async => Either.of(
          PostResult(
            posts: [testSearchPost(query == 'a' ? 1 : 2, checkedAt)],
            total: 1,
          ),
        ),
      );
      addTearDown(harness.dispose);
      harness.refreshGate = Completer<void>();
      await seedFeeds(
        tester,
        harness,
        [
          for (final id in ['a', 'b'])
            topicFixture(id: id, query: id, checked: false, unreadCount: 0),
        ],
        [
          TopicFeed(
            id: 'feed',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'Feed',
            sourceIds: const ['a', 'b'],
          ),
        ],
      );
      await pumpOverview(harness, tester);
      await drain(tester);
      expect(harness.requests.map((request) => request.query), ['a']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      harness.refreshGate!.complete();
      await drain(tester);
      expect(harness.requests.map((request) => request.query), ['a']);
      final cancelled = (await harness.repository.getById('a'))!;
      expect(cancelled.lastAttemptAt, isNull);
      expect(cancelled.lastSuccessfulCheckAt, isNull);
      expect(cancelled.previews, isEmpty);
      expect(cancelled.hasNewPosts, false);
      expect((await harness.repository.getFeeds()).single.posts, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drain(tester);
      expect(harness.requests.map((request) => request.query), ['a', 'a', 'b']);
      final manual = harness.container
          .read(followingTopicsProvider.notifier)
          .refresh('a');
      await drain(tester);
      await manual;
      expect(harness.requests.map((request) => request.query), [
        'a',
        'a',
        'b',
        'a',
      ]);
      expect(
        (await harness.repository.getById('a'))!.lastSuccessfulCheckAt,
        isNotNull,
      );
    },
  );

  final interruptions = [
    (name: 'foreground pause', isLifecycle: true),
    (name: 'network loss', isLifecycle: false),
  ];
  for (final interruption in interruptions) {
    testWidgets(
      'a queued first check discarded by ${interruption.name} retries after recovery during batch spacing',
      (tester) async {
        final manualGate = Completer<void>();
        final harness = createHarness(
          spacing: const Duration(seconds: 1),
          fetch: (query, _, _) async {
            if (query.startsWith('manual')) await manualGate.future;
            return Either.of(const PostResult(posts: <Post>[], total: 0));
          },
        );
        addTearDown(harness.dispose);
        await seedFeeds(
          tester,
          harness,
          [
            for (final id in ['manual-1', 'manual-2', 'manual-3', 'a'])
              topicFixture(id: id, query: id, checked: false),
          ],
          [
            TopicFeed(
              id: 'feed',
              profileId: '00000000-0000-4000-8000-00000000000c',
              name: 'Feed',
              sourceIds: const ['a'],
            ),
          ],
        );
        final notifier = harness.container.read(
          followingTopicsProvider.notifier,
        );
        final manual = [
          for (final id in ['manual-1', 'manual-2', 'manual-3'])
            notifier.refresh(id),
        ];
        await drain(tester);
        expect(harness.requests.map((request) => request.query), [
          'manual-1',
          'manual-2',
          'manual-3',
        ]);
        await pumpOverview(harness, tester);
        await drain(tester);
        if (interruption.isLifecycle) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          harness.container
              .read(testRefreshNetworkAllowedProvider.notifier)
              .setAllowed(false);
        }
        manualGate.complete();
        await drain(tester);
        await Future.wait(manual);
        final source = harness.container
            .read(followingTopicsProvider)
            .valueOrNull!
            .topics
            .singleWhere((search) => search.id == 'a');
        expect(source.lastAttemptAt, isNull);
        expect(source.lastSuccessfulCheckAt, isNull);
        expect(harness.requests.length, 3);
        if (interruption.isLifecycle) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else {
          harness.container
              .read(testRefreshNetworkAllowedProvider.notifier)
              .setAllowed(true);
        }
        await drain(tester);
        await tester.pump(const Duration(seconds: 1));
        await drain(tester);
        expect(harness.requests.map((request) => request.query), [
          'manual-1',
          'manual-2',
          'manual-3',
          'a',
        ]);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(seconds: 1));
          await drain(tester);
        }
        expect(harness.requests.length, 4);
      },
    );
  }

  testWidgets(
    'a started first check is not repeatedly retried when its result cannot be persisted',
    (tester) async {
      final harness = createHarness();
      addTearDown(harness.dispose);
      await seedFeeds(
        tester,
        harness,
        [topicFixture(id: 'a', query: 'a', checked: false)],
        [
          TopicFeed(
            id: 'feed',
            profileId: '00000000-0000-4000-8000-00000000000c',
            name: 'Feed',
            sourceIds: const ['a'],
          ),
        ],
      );
      harness.box.failWrites = true;
      await pumpOverview(harness, tester);
      await drain(tester);
      final source = harness.container
          .read(followingTopicsProvider)
          .valueOrNull!
          .topics
          .single;
      expect(source.lastAttemptAt, isNull);
      expect(source.lastSuccessfulCheckAt, isNull);
      expect(harness.requests.map((request) => request.query), ['a']);
      await drain(tester);
      expect(harness.requests.length, 1);
    },
  );

  final dates = [
    (age: const Duration(seconds: 15), label: 'a moment ago'),
    (age: const Duration(minutes: 1), label: 'a minute ago'),
    (age: const Duration(minutes: 8), label: '8 minutes ago'),
    (age: const Duration(hours: 1), label: 'about an hour ago'),
    (age: const Duration(hours: 3), label: '3 hours ago'),
    (age: const Duration(days: 1), label: 'a day ago'),
    (age: const Duration(days: 2), label: '2 days ago'),
    (age: const Duration(days: 90), label: '3 months ago'),
  ];
  for (final date in dates) {
    testWidgets(
      'feed status displays ${date.label} instead of a technical timestamp',
      (tester) async {
        final harness = createHarness(networkAllowed: false);
        addTearDown(harness.dispose);
        await seedFeeds(
          tester,
          harness,
          [topicFixture()],
          [
            TopicFeed(
              id: 'feed',
              profileId: '00000000-0000-4000-8000-00000000000c',
              name: 'Feed',
              sourceIds: const ['cats'],
            ),
          ],
        );
        await withClock(Clock.fixed(checkedAt.add(date.age)), () async {
          await tester.runAsync(
            () => harness.container.read(followingTopicsProvider.future),
          );
          await harness.pump(
            tester,
            const TopicFeedPage(
              feedId: 'feed',
              profileId: '00000000-0000-4000-8000-00000000000c',
            ),
          );
          expect(find.text('Last checked: ${date.label}'), findsOneWidget);
          expect(find.textContaining('2026-09-14'), findsNothing);
        });
      },
    );
  }

  testWidgets(
    'last checked uses German singular wording from the selected locale',
    (tester) async {
      final harness = createHarness(networkAllowed: false);
      addTearDown(harness.dispose);
      addTearDown(() => ensureI18nInitialized('en-US'));
      await withClock(
        Clock.fixed(checkedAt.add(const Duration(minutes: 1))),
        () async {
          await tester.runAsync(() => ensureI18nInitialized('de-DE'));
          await tester.pumpWidget(
            harness.wrap(
              MaterialApp(
                home: Scaffold(body: FeedLastChecked(checkedAt: checkedAt)),
                builder: themeBuilder,
              ),
            ),
          );
          await settle(tester);
          expect(find.text('Last checked: vor einer Minute'), findsOneWidget);
          expect(find.textContaining('1 Minuten'), findsNothing);
        },
      );
    },
  );

  testWidgets('feed status shows a localized never-checked state', (
    tester,
  ) async {
    final harness = createHarness(networkAllowed: false);
    addTearDown(harness.dispose);
    await seedFeeds(
      tester,
      harness,
      [topicFixture(checked: false)],
      [
        TopicFeed(
          id: 'feed',
          profileId: '00000000-0000-4000-8000-00000000000c',
          name: 'Feed',
          sourceIds: const ['cats'],
        ),
      ],
    );
    await tester.runAsync(
      () => harness.container.read(followingTopicsProvider.future),
    );
    await harness.pump(
      tester,
      const TopicFeedPage(
        feedId: 'feed',
        profileId: '00000000-0000-4000-8000-00000000000c',
      ),
    );
    expect(find.text('Never checked'), findsOneWidget);
  });
}

Future<void> seedFeeds(
  WidgetTester tester,
  FollowingTopicHarness harness,
  List<FollowingTopic> sources,
  List<TopicFeed> feeds,
) async {
  await tester.runAsync(() async {
    await harness.seed(sources);
    for (final feed in feeds) {
      await harness.organizationBox.put('feed:${feed.id}', feed.toJson());
    }
    await harness.container.read(followingTopicsProvider.future);
  });
}

Future<void> pumpOverview(
  FollowingTopicHarness harness,
  WidgetTester tester, {
  Key? key,
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await harness.pump(
    tester,
    SearchRefreshLifecycle(child: TopicFeedsPage(key: key)),
  );
}
