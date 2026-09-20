import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'pinned_search_test_utils.dart';

void main() {
  for (final c in [
    (name: 'Main', otherName: 'Other', expected: 'Main'),
    (
      name: 'Shared',
      otherName: 'Shared',
      expected: 'Shared · https://active.example',
    ),
  ]) {
    testWidgets('profile footnotes distinguish ${c.name} from ${c.otherName}', (
      tester,
    ) async {
      final harness = PinnedSearchHarness(
        profiles: [
          BooruConfig.fromJson({...testProfile.toJson(), 'name': c.name}),
          BooruConfig.fromJson({
            ...otherTestProfile.toJson(),
            'name': c.otherName,
          }),
        ],
      );
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture()]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text(c.expected), findsOneWidget);
    });
  }

  testWidgets(
    'Home shows all owners without profile groups and browsing keeps the active profile',
    (tester) async {
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([
          pinnedFixture(query: 'cat'),
          pinnedFixture(
            id: 'other',
            profileId: 99,
            name: 'Other search',
            query: 'dog',
          ),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text('Cats'), findsOneWidget);
      expect(find.text('Other search'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Unfiled'), findsNothing);
      expect(find.byTooltip('Manage folders'), findsOneWidget);
      expect(find.text('https://active.example'), findsOneWidget);
      expect(find.text('https://other.example'), findsOneWidget);
      expect(harness.container.read(currentBooruConfigProvider).id, 12);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'opening another profile search switches to its owner and marks only that search read',
    (tester) async {
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([
          pinnedFixture(query: 'cat'),
          pinnedFixture(
            id: 'other',
            profileId: 99,
            name: 'Other search',
            query: 'dog',
          ),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      int? owner;
      harness.router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PinnedSearchesPage()),
          GoRoute(
            path: '/search',
            builder: (_, state) {
              owner = harness.container.read(currentBooruConfigProvider).id;
              return Scaffold(
                body: Text('Opened ${state.uri.queryParameters['query']}'),
              );
            },
          ),
        ],
      );
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(
        harness.wrap(
          MaterialApp.router(
            routerConfig: harness.router,
            builder: themeBuilder,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Other search'));
      await drain(tester);
      expect(owner, 99);
      expect(find.text('Opened dog'), findsOneWidget);
      final saved = await tester.runAsync(() => harness.repository.getAll());
      expect(saved!.singleWhere((s) => s.id == 'cats').hasNewPosts, true);
      expect(saved.singleWhere((s) => s.id == 'other').hasNewPosts, false);
    },
  );

  testWidgets(
    'Refresh All checks searches from every owning profile without changing the active profile',
    (tester) async {
      final harness = PinnedSearchHarness();
      addTearDown(harness.dispose);
      await tester.runAsync(() async {
        await harness.seed([
          pinnedFixture(query: 'cat'),
          pinnedFixture(
            id: 'other',
            profileId: 99,
            name: 'Other search',
            query: 'dog',
          ),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      await tester.tap(find.byTooltip('Refresh All'));
      await drain(tester);
      expect(harness.requests.map((r) => r.profileId), [12, 99]);
      expect(harness.container.read(currentBooruConfigProvider).id, 12);
    },
  );
}
