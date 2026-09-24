import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/routes.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
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

  for (final scenario in ['existing', 'home', 'create', 'cancel', 'failure']) {
    testWidgets(
      'moving a pin to $scenario preserves its owner and commits only on success',
      (tester) async {
        initialize();
        await harness.seed([
          pinnedFixture(),
          pinnedFixture(id: 'dogs', profileId: 99, name: 'Dogs'),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        final oldFolder = await notifier.createSharedFolder('Original');
        final otherFolder = await notifier.createSharedFolder(
          'Other owner folder',
        );
        await notifier.movePinToSharedFolder('cats', oldFolder.id);
        await notifier.movePinToSharedFolder('dogs', otherFolder.id);
        await harness.pump(tester, PinnedSearchesPage(folderId: oldFolder.id));
        await choose(tester, 'Move to folder');
        expect(find.text('[Home]'), findsOneWidget);
        expect(find.text('Other owner folder'), findsOneWidget);
        expect(find.text('Create folder'), findsOneWidget);
        if (scenario == 'existing' || scenario == 'home') {
          await tester.tap(
            find.text(scenario == 'home' ? '[Home]' : 'Other owner folder'),
          );
        } else {
          await tester.tap(find.text('Create folder'));
          await settle(tester);
          expect(find.textContaining('any profile'), findsNothing);
          await tester.enterText(
            find.byType(TextField),
            scenario == 'failure' ? 'Original' : 'New folder',
          );
          await tester.pump();
          await tester.tap(find.text(scenario == 'cancel' ? 'Cancel' : 'Save'));
        }
        await settle(tester);
        await drain(tester);
        final organization = await harness.repository.getOrganization();
        final destination = organization.folders
            .where((f) => f.searchIds.contains('cats'))
            .firstOrNull;
        expect((await harness.repository.getById('cats'))!.profileId, 12);
        switch (scenario) {
          case 'existing':
            expect(destination?.id, otherFolder.id);
          case 'home':
            expect(organization.homeSearchIds, contains('cats'));
          case 'create':
            expect(destination?.name, 'New folder');
          case 'cancel' || 'failure':
            expect(destination?.id, oldFolder.id);
        }
        if (scenario == 'failure') {
          expect(
            find.text('Could not update the pinned search. Try again.'),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 5));
        }
      },
    );
  }

  testWidgets(
    'unsupported profiles keep their cached pins visible and disable refresh all',
    (tester) async {
      harness = PinnedSearchHarness(supported: false);
      addTearDown(harness.dispose);
      await harness.seed([pinnedFixture()]);
      await pump(tester);
      expect(find.text('Pinned Searches'), findsOneWidget);
      expect(find.text('Cats'), findsOneWidget);
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

  testWidgets('shows the cached last post time on the profile metadata line', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
      initialize();
      await harness.seed([
        pinnedFixture(
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 14, 10),
        ),
      ]);
      await pump(tester);

      expect(find.text('Last post: 2 hours ago'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Last post: 2 hours ago')).dy,
        tester.getCenter(find.text('https://active.example')).dy,
      );
      expect(
        tester.getTopRight(find.byType(PinnedSearchCard)).dx -
            tester.getTopRight(find.text('Last post: 2 hours ago')).dx,
        lessThan(32),
      );
      expect(harness.requests, isEmpty);
    });
  });

  testWidgets('long profile captions truncate before the last post time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longUrl = 'https://a-very-long-profile-name.example.test';
    final profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': 12,
      'url': longUrl,
    });
    harness = PinnedSearchHarness(profiles: [profile, otherTestProfile]);
    addTearDown(harness.dispose);
    harness.container
        .read(selectedTestProfileProvider.notifier)
        .select(profile);
    await harness.seed([
      pinnedFixture(
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 14, 10),
      ),
    ]);

    await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
      await harness.pump(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PinnedSearchesPage(),
        ),
      );
    });

    final caption = tester.widget<Text>(find.text(longUrl));
    expect(caption.maxLines, 1);
    expect(caption.overflow, TextOverflow.ellipsis);
    expect(find.text('Last post: 2 hours ago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates the relative last post time while the page stays open', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 14, 12);
    initialize();
    await harness.seed([
      pinnedFixture(
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 14, 10),
      ),
    ]);

    await withClock(Clock(() => now), () async {
      await pump(tester);
      expect(find.text('Last post: 2 hours ago'), findsOneWidget);

      now = DateTime.utc(2026, 9, 14, 13);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Last post: 3 hours ago'), findsOneWidget);
    });
  });

  for (final c in [
    (checked: false, label: 'Last post: Not checked'),
    (checked: true, label: 'Last post: No posts'),
  ]) {
    testWidgets('shows ${c.label} when no cached post time is available', (
      tester,
    ) async {
      initialize();
      await harness.seed([pinnedFixture(checked: c.checked)]);
      await pump(tester);

      expect(find.text(c.label), findsOneWidget);
      expect(harness.requests, isEmpty);
    });
  }

  testWidgets('keeps the cached last post time beside a refresh error', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
      initialize();
      await harness.seed([
        pinnedFixture(
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 14, 10),
          error: SearchRefreshErrorKind.network,
        ),
      ]);
      await pump(tester);

      expect(find.text('Last post: 2 hours ago'), findsOneWidget);
      expect(
        find.text('Could not connect. Try refreshing again.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'newest post view reorders cards without changing manual order',
    (tester) async {
      initialize();
      await harness.seed([
        pinnedFixture(
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 12),
        ),
        pinnedFixture(
          id: 'dogs',
          name: 'Dogs',
          query: 'dog',
          position: 1,
          previewCount: 1,
          postCreatedAt: DateTime.utc(2026, 9, 13),
        ),
      ]);
      await pump(tester);

      await tester.tap(find.byTooltip('Sort by'));
      await settle(tester);
      await tester.tap(find.text('Last post: newest first'));
      await settle(tester);

      expect(
        tester.getTopLeft(find.text('Dogs')).dy,
        lessThan(tester.getTopLeft(find.text('Cats')).dy),
      );
      expect((await harness.repository.getOrganization()).homeSearchIds, [
        'cats',
        'dogs',
      ]);
      expect(harness.requests, isEmpty);

      await tester.tap(find.byTooltip('Sort by'));
      await settle(tester);
      await tester.tap(find.text('Manual order'));
      await settle(tester);
      expect(
        tester.getTopLeft(find.text('Cats')).dy,
        lessThan(tester.getTopLeft(find.text('Dogs')).dy),
      );
    },
  );

  testWidgets('oldest post view keeps undated cards after dated cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    initialize();
    await harness.seed([
      pinnedFixture(name: 'Not checked', checked: false),
      pinnedFixture(
        id: 'newer',
        name: 'Newer',
        query: 'newer',
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 13),
      ),
      pinnedFixture(
        id: 'older',
        name: 'Older',
        query: 'older',
        position: 2,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
    ]);
    await pump(tester);

    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Last post: oldest first'));
    await settle(tester);

    expect(
      tester.getTopLeft(find.text('Older')).dy,
      lessThan(tester.getTopLeft(find.text('Newer')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Newer')).dy,
      lessThan(tester.getTopLeft(find.text('Not checked')).dy),
    );
  });

  testWidgets('date views disable manual move actions', (tester) async {
    initialize();
    await harness.seed([
      pinnedFixture(
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
      pinnedFixture(
        id: 'dogs',
        name: 'Dogs',
        query: 'dog',
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 13),
      ),
    ]);
    await pump(tester);
    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Last post: newest first'));
    await settle(tester);
    await openMenu(tester, 'Dogs');

    for (final label in ['Move up', 'Move down']) {
      final item = tester.widget<PopupMenuItem<PinnedSearchAction>>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(PopupMenuItem<PinnedSearchAction>),
        ),
      );
      expect(item.enabled, isFalse);
    }
  });

  testWidgets('selected date view carries from Home into a folder', (
    tester,
  ) async {
    initialize();
    await harness.seed([
      pinnedFixture(
        name: 'Newer',
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 13),
      ),
      pinnedFixture(
        id: 'older',
        name: 'Older',
        query: 'older',
        position: 1,
        previewCount: 1,
        postCreatedAt: DateTime.utc(2026, 9, 12),
      ),
    ]);
    final notifier = harness.container.read(
      searchSubscriptionsProvider.notifier,
    );
    final folder = await notifier.createSharedFolder('Favorites');
    await notifier.movePinToSharedFolder('cats', folder.id);
    await notifier.movePinToSharedFolder('older', folder.id);
    await pump(tester);

    await tester.tap(find.byTooltip('Sort by'));
    await settle(tester);
    await tester.tap(find.text('Last post: oldest first'));
    await settle(tester);
    await tester.tap(find.text('Favorites'));
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Favorites'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Older')).dy,
      lessThan(tester.getTopLeft(find.text('Newer')).dy),
    );
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

  testWidgets('shows cached cards from all profiles without requesting posts', (
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
        query: 'other',
        unreadCount: 90,
      ),
    ]);
    await pump(tester);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('cat  rating:safe order:score'), findsOneWidget);
    expect(find.text('dog'), findsOneWidget);
    expect(find.text('Other profile'), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(2));
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
      kind: SearchRefreshErrorKind.tagLimit,
      message: "This search exceeds the site's search-term limit.",
    ),
    (
      kind: SearchRefreshErrorKind.rateLimited,
      message: 'Rate limited by the site. Try again later.',
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

  testWidgets(
    'move up and down order Home across profiles without changing owners',
    (tester) async {
      initialize();
      await harness.seed([
        pinnedFixture(),
        pinnedFixture(id: 'dogs', name: 'Dogs', query: 'dog', profileId: 99),
      ]);
      await pump(tester);
      await choose(tester, 'Move down');
      expect(
        tester.getTopLeft(find.text('Dogs')).dy,
        lessThan(tester.getTopLeft(find.text('Cats')).dy),
      );
      expect((await harness.repository.getOrganization()).homeSearchIds, [
        'dogs',
        'cats',
      ]);
      expect((await harness.repository.getById('dogs'))!.profileId, 99);
      await choose(tester, 'Move up');
      expect((await harness.repository.getOrganization()).homeSearchIds, [
        'cats',
        'dogs',
      ]);
    },
  );

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
      pinnedFixture(id: 'other', profileId: 99, name: 'Other'),
    ]);
    await pump(tester);
    await choose(tester, 'Refresh');
    expect(find.text('Refreshing…'), findsOneWidget);
    expect(harness.requests.map((request) => request.profileId), [12]);
    harness.refreshGate!.complete();
    await settle(tester);
    expect(find.text('Refreshing…'), findsNothing);
  });

  testWidgets(
    'Refresh All visits both owners and remains disabled while a batch runs',
    (tester) async {
      initialize();
      harness.refreshGate = Completer<void>();
      await harness.seed([
        pinnedFixture(checked: false, query: 'cat'),
        pinnedFixture(
          id: 'other',
          profileId: 99,
          name: 'Other',
          query: 'dog',
          checked: false,
        ),
      ]);
      await pump(tester);
      await tester.tap(find.byTooltip('Refresh All'));
      await settle(tester);
      expect(harness.requests.map((r) => r.profileId), [12]);
      expect(refreshAllButton(tester).onPressed, isNull);
      harness.container
          .read(selectedTestProfileProvider.notifier)
          .select(otherTestProfile);
      await pump(tester);
      expect(refreshAllButton(tester).onPressed, isNull);
      harness.refreshGate!.complete();
      await settle(tester);
      await drain(tester);
      expect(harness.requests.map((r) => r.profileId), [12, 99]);
      expect(refreshAllButton(tester).onPressed, isNotNull);
      expect(
        (await harness.repository.getById('other'))!.lastSuccessfulCheckAt,
        isNotNull,
      );
    },
  );

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
