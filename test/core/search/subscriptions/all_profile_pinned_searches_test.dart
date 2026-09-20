import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';

Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'profile groups collapse independently and cached browsing does not switch profiles',
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
      expect(find.text('Other search'), findsNothing);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('pinned_profile_99')),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await settle(tester);
      expect(find.text('Other search'), findsOneWidget);
      expect(harness.container.read(currentBooruConfigProvider).id, 12);
      expect(harness.requests, isEmpty);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('pinned_profile_12')),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await settle(tester);
      expect(find.text('Cats'), findsNothing);
      expect(find.text('Other search'), findsOneWidget);
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
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('pinned_profile_99')),
              matching: find.byType(ListTile),
            )
            .first,
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
