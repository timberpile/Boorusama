import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/routes.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  Uri? openedUri;

  void initialize({Completer<void>? ready, bool loadImages = false}) {
    harness = PinnedSearchHarness(
      repositoryReady: ready,
      loadImages: loadImages,
    );
    addTearDown(harness.dispose);
    openedUri = null;
  }

  Future<void> pump(WidgetTester tester) =>
      harness.pump(tester, const PinnedSearchesPage());

  IconButton refreshAllButton(WidgetTester tester) => tester.widget<IconButton>(
    find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Refresh All',
    ),
  );

  Future<void> openMenu(WidgetTester tester, [String name = 'Cats']) async {
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(PinnedSearchCard),
    );
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byType(PopupMenuButton<PinnedSearchAction>),
      ),
    );
    await settle(tester);
  }

  Future<void> choose(
    WidgetTester tester,
    String label, [
    String name = 'Cats',
  ]) async {
    await openMenu(tester, name);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  Future<void> pumpRouter(WidgetTester tester) async {
    harness.router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [pinnedSearchRoutes],
        ),
        GoRoute(
          path: '/search',
          builder: (_, state) {
            openedUri = state.uri;
            return Scaffold(
              body: Text('Opened ${state.uri.queryParameters['query']}'),
            );
          },
        ),
      ],
      initialLocation: '/pinned-searches',
    );
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(
      harness.wrap(
        MaterialApp.router(routerConfig: harness.router, builder: themeBuilder),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'an unsupported tab explains support and preserves existing pins',
    (tester) async {
      harness = PinnedSearchHarness(supported: false);
      addTearDown(harness.dispose);
      await harness.seed([pinnedFixture()]);
      await pump(tester);
      expect(find.text('Pinned Searches'), findsOneWidget);
      expect(
        find.text('Pinned searches are not supported for this profile.'),
        findsOneWidget,
      );
      expect(harness.requests, isEmpty);
      expect((await harness.repository.getAll()).single.id, 'cats');
      expect(refreshAllButton(tester).onPressed, isNull);
    },
  );

  testWidgets('routine check details are available through Info only', (
    tester,
  ) async {
    initialize();
    await harness.seed([pinnedFixture()]);
    await pump(tester);
    expect(find.textContaining('Last checked:'), findsNothing);
    await choose(tester, 'Info');
    expect(find.textContaining('Last checked:'), findsOneWidget);
    expect(harness.requests, isEmpty);
  });

  testWidgets('shows loading before cached searches become available', (
    tester,
  ) async {
    final ready = Completer<void>();
    initialize(ready: ready);
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete();
    await settle(tester);
    expect(find.text('No pinned searches yet'), findsOneWidget);
  });

  testWidgets('reports a storage load failure and allows retrying', (
    tester,
  ) async {
    final ready = Completer<void>();
    initialize(ready: ready);
    await pump(tester);
    ready.completeError(StateError('unavailable'));
    await settle(tester);
    expect(find.text('Could not load pinned searches.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows cached active-profile cards without requesting posts', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      pinnedFixture(previewCount: 6, error: SearchRefreshErrorKind.network),
      pinnedFixture(
        id: 'dogs',
        query: 'dog',
        name: null,
        position: 1,
        unreadCount: 0,
        checked: false,
      ),
      pinnedFixture(
        id: 'other',
        profileId: 99,
        name: 'Other profile',
        unreadCount: 90,
      ),
    ]);
    await pump(tester);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('cat  rating:safe order:score'), findsOneWidget);
    expect(find.text('dog'), findsOneWidget);
    expect(find.text('Other profile'), findsNothing);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Never checked'), findsNothing);
    expect(find.textContaining('Last checked:'), findsNothing);
    expect(
      find.text('Could not connect. Try refreshing again.'),
      findsOneWidget,
    );
    final images = tester
        .widgetList<BooruImage>(find.byType(BooruImage))
        .toList();
    expect(images.map((image) => image.imageUrl), [
      'https://images.example/0.jpg',
      'https://images.example/1.jpg',
      'https://images.example/2.jpg',
      'https://images.example/3.jpg',
    ]);
    expect(images.every((image) => image.config == testProfile.auth), isTrue);
    for (final element in find.byType(BooruImage).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.width, size.height);
    }
    expect(harness.requests, isEmpty);
  });

  for (final c in [
    (
      kind: SearchRefreshErrorKind.authentication,
      message: 'Check this profile’s login details.',
    ),
    (
      kind: SearchRefreshErrorKind.query,
      message: 'This query could not be checked.',
    ),
    (
      kind: SearchRefreshErrorKind.pagination,
      message: 'The check was incomplete. Try refreshing again.',
    ),
    (
      kind: SearchRefreshErrorKind.parsing,
      message: 'The site returned unreadable post data.',
    ),
    (
      kind: SearchRefreshErrorKind.unsupported,
      message: 'New-post tracking is unsupported for this search.',
    ),
    (
      kind: SearchRefreshErrorKind.other,
      message: 'Could not refresh this search. Try again.',
    ),
  ]) {
    testWidgets('presents a stable ${c.kind.name} refresh error', (
      tester,
    ) async {
      initialize();
      await harness.seed([pinnedFixture(error: c.kind)]);
      await pump(tester);
      expect(find.text(c.message), findsOneWidget);
      expect(find.textContaining('Last checked:'), findsNothing);
    });
  }

  testWidgets('a broken cached preview uses the existing image fallback', (
    tester,
  ) async {
    initialize(loadImages: true);
    await harness.seed([pinnedFixture(previewCount: 1)]);
    await pump(tester);
    for (
      var i = 0;
      i < 15 && find.byType(ErrorPlaceholder).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(ErrorPlaceholder), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(harness.requests, isEmpty);
  });

  testWidgets(
    'awaits clearing unread before opening the exact stored simple query',
    (tester) async {
      initialize();
      await harness.seed([pinnedFixture()]);
      await pumpRouter(tester);
      harness.box.writeGate = Completer<void>();
      await tester.tap(find.text('Cats'));
      await settle(tester);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/pinned-searches',
      );
      harness.box.writeGate!.complete();
      await settle(tester);
      await settle(tester);
      expect((await harness.repository.getById('cats'))!.unreadCount, 0);
      expect(openedUri!.path, '/search');
      expect(find.text('Opened cat  rating:safe order:score'), findsOneWidget);
      expect(openedUri!.queryParameters['query_type'], 'simple');
    },
  );

  testWidgets(
    'keeps the card unread and stays on the page when mark-read fails',
    (tester) async {
      initialize();
      await harness.seed([pinnedFixture()]);
      await pumpRouter(tester);
      harness.box.failWrites = true;
      await tester.tap(find.text('Cats'));
      await settle(tester);
      expect((await harness.repository.getById('cats'))!.unreadCount, 1);
      expect(find.byType(PinnedSearchesPage), findsOneWidget);
      expect(
        find.text('Could not mark this search as read. Try again.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'renaming to blank restores the query label without changing unread',
    (tester) async {
      initialize();
      await harness.seed([pinnedFixture()]);
      await pump(tester);
      await choose(tester, 'Rename');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Cats',
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Cats'), findsNothing);
      expect(find.text('cat  rating:safe order:score'), findsOneWidget);
      expect((await harness.repository.getById('cats'))!.unreadCount, 1);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('move up and down manually order only the active profile', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      pinnedFixture(),
      pinnedFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
      pinnedFixture(id: 'birds', name: 'Birds', query: 'bird', position: 2),
      pinnedFixture(id: 'other', profileId: 99, name: 'Other profile'),
    ]);
    await pump(tester);
    await openMenu(tester);
    final up = tester.widget<PopupMenuItem<PinnedSearchAction>>(
      find.ancestor(
        of: find.text('Move up'),
        matching: find.byType(PopupMenuItem<PinnedSearchAction>),
      ),
    );
    expect(up.enabled, isFalse);
    await tester.tap(find.text('Move down'));
    await settle(tester);
    expect(
      tester.getTopLeft(find.text('Dogs')).dy,
      lessThan(tester.getTopLeft(find.text('Cats')).dy),
    );
    expect(find.byType(ReorderableListView), findsNothing);
    await choose(tester, 'Move down', 'Dogs');
    await choose(tester, 'Move down', 'Dogs');
    expect(
      harness.container
          .read(profilePinnedSearchesProvider(12))
          .requireValue
          .map((item) => item.id),
      ['cats', 'birds', 'dogs'],
    );
    expect((await harness.repository.getById('other'))!.position, 0);
    await choose(tester, 'Move up', 'Birds');
    expect(
      tester.getTopLeft(find.text('Birds')).dy,
      lessThan(tester.getTopLeft(find.text('Cats')).dy),
    );
    await openMenu(tester, 'Dogs');
    final down = tester.widget<PopupMenuItem<PinnedSearchAction>>(
      find.ancestor(
        of: find.text('Move down'),
        matching: find.byType(PopupMenuItem<PinnedSearchAction>),
      ),
    );
    expect(down.enabled, isFalse);
  });

  testWidgets(
    'delete waits for confirmation and removes the card immediately',
    (tester) async {
      initialize();
      await harness.seed([pinnedFixture()]);
      await pump(tester);
      await choose(tester, 'Delete');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Cats'), findsOneWidget);
      await choose(tester, 'Delete');
      expect(find.text('Delete “Cats”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(find.text('Cats'), findsNothing);
      expect(find.text('No pinned searches yet'), findsOneWidget);
      expect(await harness.repository.getAll(), isEmpty);
    },
  );

  testWidgets('refreshes one card and displays its running state', (
    tester,
  ) async {
    initialize();
    harness.refreshGate = Completer<void>();
    await harness.seed([
      pinnedFixture(query: 'cat'),
      pinnedFixture(id: 'other', profileId: 99),
    ]);
    await pump(tester);
    await choose(tester, 'Refresh');
    expect(find.text('Refreshing…'), findsOneWidget);
    expect(harness.requests.map((request) => request.profileId), [12]);
    harness.refreshGate!.complete();
    await settle(tester);
    expect(find.text('Refreshing…'), findsNothing);
  });

  testWidgets('Refresh All shows progress only for the batch owning profile', (
    tester,
  ) async {
    initialize();
    harness.refreshGate = Completer<void>();
    await harness.seed([
      pinnedFixture(checked: false, query: 'cat'),
      pinnedFixture(
        id: 'dogs',
        query: 'dog',
        name: 'Dogs',
        position: 1,
        checked: false,
      ),
      pinnedFixture(
        id: 'other',
        profileId: 99,
        name: 'Other profile',
        checked: false,
      ),
    ]);
    await pump(tester);
    await tester.tap(find.byTooltip('Refresh All'));
    await settle(tester);
    expect(harness.requests.map((request) => request.profileId), [12, 12]);
    expect(find.text('Refreshing 0 of 2'), findsOneWidget);
    expect(
      refreshAllButton(tester).onPressed,
      isNull,
    );
    expect(
      harness.container
          .read(searchSubscriptionsProvider)
          .requireValue
          .batchProfileId,
      12,
    );
    harness.container
        .read(selectedTestProfileProvider.notifier)
        .select(otherTestProfile);
    await settle(tester);
    expect(find.text('Refreshing 0 of 2'), findsNothing);
    expect(
      refreshAllButton(tester).onPressed,
      isNotNull,
    );
    harness.container
        .read(selectedTestProfileProvider.notifier)
        .select(testProfile);
    await settle(tester);
    expect(find.text('Refreshing 0 of 2'), findsOneWidget);
    harness.refreshGate!.complete();
    await settle(tester);
    expect(find.text('Refreshing 0 of 2'), findsNothing);
    expect(
      refreshAllButton(tester).onPressed,
      isNotNull,
    );
    expect(
      (await harness.repository.getById('other'))!.lastSuccessfulCheckAt,
      isNull,
    );
  });

  testWidgets(
    'a completed mark-read does not navigate after the page is disposed',
    (tester) async {
      initialize();
      await harness.seed([pinnedFixture()]);
      await pumpRouter(tester);
      harness.box.writeGate = Completer<void>();
      await tester.tap(find.text('Cats'));
      await settle(tester);
      harness.router.go('/');
      await settle(tester);
      harness.box.writeGate!.complete();
      await settle(tester);
      expect(harness.router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
    },
  );
}
