import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/routes.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_navigation_icon.dart';
import 'package:kurumi/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'following_topic_test_utils.dart';

void main() {
  late FollowingTopicHarness harness;
  void initialize() {
    harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
  }

  Finder pinnedBadge(bool compact) => find.descendant(
    of: find.byType(FollowingTopicNavigationIcon),
    matching: find.byType(Badge),
  );
  Future<void> mountShell(WidgetTester tester, {required bool compact}) async {
    tester.view.physicalSize = Size(compact ? 390 : 1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const browse = DestinationId.browse('a');
    const following = DestinationId.app(AppDestination.following);
    late DestinationRouterBinding binding;
    binding = DestinationRouterBinding(
      definitions: [
        DestinationRouteDefinition(
          id: browse,
          builder: (_, _) => const Scaffold(),
        ),
        DestinationRouteDefinition(
          id: following,
          builder: (_, _) => const FollowingTopicsPage(),
        ),
      ],
      shellBuilder: (_, _, shell) => Consumer(
        builder: (_, ref, _) => AppNavigationShell(
          navigationShell: shell,
          active: binding.idAt(shell.currentIndex),
          browse: browse,
          catalog: NavigationCatalog(
            profileSections: [],
            globalEntries: [],
            eligibleFavoritesProfileIds: [],
          ),
          collapsedProfiles: const {},
          hasNewFollowingPosts: ref.watch(followingTopicHasNewPostsProvider),
          onSelect: (id) async => binding.select(id),
          onFavorites: () async => false,
          onToggleProfile: (_) {},
        ),
      ),
    );
    harness.router = GoRouter.routingConfig(
      routingConfig: binding.routingConfig,
      initialLocation: browse.location,
    );
    binding.attach(harness.router);
    addTearDown(harness.router.dispose);
    addTearDown(binding.dispose);
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(routerConfig: harness.router, builder: themeBuilder),
      ),
    );
    await settle(tester);
  }

  for (final c in [
    (name: 'compact', mobile: true),
    (name: 'wide', mobile: false),
  ]) {
    testWidgets(
      '${c.name} NEW badges cover all profiles and clear after reading all topics',
      (tester) async {
        initialize();
        await harness.seed([
          topicFixture(),
          topicFixture(
            id: 'dogs',
            query: 'dog',
            name: 'Dogs',
            position: 1,
            unreadCount: 5,
          ),
          topicFixture(
            id: 'other',
            profileId: '00000000-0000-4000-8000-000000000063',
            unreadCount: 90,
          ),
        ]);
        await mountShell(tester, compact: c.mobile);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        expect(find.text('8'), findsNothing);
        expect(find.text('90'), findsNothing);
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('cats');
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(otherTestProfile);
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('other');
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        harness.container
            .read(selectedTestProfileProvider.notifier)
            .select(testProfile);
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsOneWidget);
        await harness.container
            .read(followingTopicsProvider.notifier)
            .markRead('dogs');
        await settle(tester);
        expect(pinnedBadge(c.mobile), findsNothing);
        expect(find.text('Following'), findsOneWidget);
      },
    );
  }

  for (final legacyPath in ['/pinned-searches', '/following-feeds']) {
    testWidgets('legacy deep link $legacyPath redirects to Following Topics', (
      tester,
    ) async {
      await tester.runAsync(() async {
        initialize();
      });
      harness.router = GoRouter(
        initialLocation: legacyPath,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(),
            routes: [
              followingTopicRoutes,
              ...legacyFollowingTopicRoutes,
            ],
          ),
        ],
      );
      addTearDown(harness.router.dispose);
      await tester.runAsync(
        () => harness.container.read(followingTopicsProvider.future),
      );
      await tester.pumpWidget(
        harness.wrap(
          MaterialApp.router(
            routerConfig: harness.router,
            builder: themeBuilder,
          ),
        ),
      );
      await drain(tester);
      await tester.pumpAndSettle();
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/following-topics',
      );
      expect(find.byType(FollowingTopicsPage), findsOneWidget);
    });
  }
}
