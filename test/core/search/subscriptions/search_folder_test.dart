import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/pages/pinned_searches_page.dart';
import 'package:boorusama/core/search/subscriptions/src/widgets/pinned_search_card.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness harness;
  setUp(() {
    harness = PinnedSearchHarness();
  });
  tearDown(() => harness.dispose());

  Finder pageOverflow() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('More'),
  );

  Finder folderCard(String folderId) => find.byKey(
    ValueKey('pinned-search-folder-$folderId'),
  );

  Future<void> openFolderMenu(WidgetTester tester, String folderId) async {
    await tester.tap(
      find.descendant(
        of: folderCard(folderId),
        matching: find.byType(PopupMenuButton<PinnedSearchAction>),
      ),
    );
    await settle(tester);
  }

  Future<void> chooseFolderAction(
    WidgetTester tester,
    String folderId,
    String label,
  ) async {
    await openFolderMenu(tester, folderId);
    await tester.tap(find.text(label).last);
    await settle(tester);
    await drain(tester);
  }

  PopupMenuItem actionItem(WidgetTester tester, String label) =>
      tester.widget<PopupMenuItem>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem,
          ),
        ),
      );

  Future<void> dismissMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(1, 1));
    await settle(tester);
  }

  SearchSubscription cachedFixture({
    required String id,
    required List<DateTime?> postCreatedAts,
    bool checked = true,
  }) => SearchSubscription(
    id: id,
    profileId: 12,
    query: id,
    name: id,
    position: 0,
    createdAt: checkedAt,
    previews: [
      for (final (index, postCreatedAt) in postCreatedAts.indexed)
        SearchPostPreview(
          postId: index,
          postCreatedAt: postCreatedAt,
          thumbnailUrl: 'https://images.example/$id-$index.jpg',
          sampleUrl: null,
          discoveredAt: checkedAt,
        ),
    ],
    recentPostIdentities: const [],
    unreadCount: 0,
    lastSuccessfulCheckAt: checked ? checkedAt : null,
  );

  test(
    'shared folders order pins from different profiles and leave Home ungrouped',
    () async {
      final cats = pinnedFixture(query: 'cat');
      final dogs = pinnedFixture(
        id: 'dogs',
        name: 'Dogs',
        profileId: 99,
        query: 'dog',
      );
      await harness.seed([cats, dogs]);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      await harness.container.read(searchSubscriptionsProvider.future);

      final folder = await notifier.createSharedFolder('Animals');
      await notifier.movePinToSharedFolder(cats.id, folder.id);
      await notifier.movePinToSharedFolder(dogs.id, folder.id);
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [cats.id, dogs.id],
      );

      await notifier.reorderSharedPins(folder.id, 1, 0);
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [dogs.id, cats.id],
      );

      await notifier.reorderSharedPins(folder.id, 0, 1);
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [cats.id, dogs.id],
      );

      await notifier.movePinToSharedFolder(cats.id, null);
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(folder.id))
            .requireValue
            .map((search) => search.id),
        [dogs.id],
      );
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(null))
            .requireValue
            .map((search) => search.id),
        [cats.id],
      );
      expect(
        harness.container
            .read(organizedPinnedSearchesProvider(folder.id))
            .requireValue
            .any((search) => search.hasNewPosts),
        isTrue,
      );
    },
  );

  testWidgets(
    'creating a folder from More keeps text input alive through dialog closing',
    (tester) async {
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.byTooltip('Manage folders'), findsNothing);
      await tester.tap(pageOverflow());
      await settle(tester);
      await tester.tap(find.text('Create folder'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Animals');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      for (var i = 0; i < 20 && find.byType(Card).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(find.text('Animals'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder cards refresh, rename, reorder, and confirm unpinning across owners',
    (tester) async {
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([
          pinnedFixture(query: 'cat'),
          pinnedFixture(
            id: 'dogs',
            profileId: 99,
            name: 'Dogs',
            query: 'dog',
          ),
          pinnedFixture(id: 'home', name: 'Home pin'),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        folderId = folder.id;
        await notifier.movePinToSharedFolder('cats', folderId);
        await notifier.movePinToSharedFolder('dogs', folderId);
        await notifier.createSharedFolder('Other folder');
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text('2 items'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Animals')).dy,
        lessThan(tester.getTopLeft(find.text('Home pin')).dy),
      );
      expect(
        find.descendant(
          of: folderCard(folderId),
          matching: find.byType(Card),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: folderCard(folderId),
          matching: find.text('NEW'),
        ),
        findsOneWidget,
      );
      await chooseFolderAction(tester, folderId, 'Refresh');
      expect(harness.requests, [
        (profileId: 12, query: 'cat'),
        (profileId: 99, query: 'dog'),
      ]);
      await chooseFolderAction(tester, folderId, 'Rename');
      await tester.enterText(find.byType(TextField), 'Pets');
      await tester.tap(find.text('Save'));
      await settle(tester);
      await drain(tester);
      expect(find.text('Pets'), findsOneWidget);
      await chooseFolderAction(tester, folderId, 'Move down');
      expect(
        tester.getTopLeft(find.text('Other folder')).dy,
        lessThan(tester.getTopLeft(find.text('Pets')).dy),
      );
      await chooseFolderAction(tester, folderId, 'Move up');
      expect(
        tester.getTopLeft(find.text('Pets')).dy,
        lessThan(tester.getTopLeft(find.text('Other folder')).dy),
      );
      await chooseFolderAction(tester, folderId, 'Delete');
      expect(find.text('Delete “Pets”?'), findsOneWidget);
      expect(
        find.text('This will unpin all 2 searches in this folder.'),
        findsOneWidget,
      );
      expect(find.text('Unpinning cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await drain(tester);
      expect(
        harness.container
            .read(searchSubscriptionsProvider)
            .requireValue
            .subscriptions
            .length,
        3,
      );
      await chooseFolderAction(tester, folderId, 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      await drain(tester);
      expect(find.text('Pets'), findsNothing);
      expect(
        harness.container
            .read(searchSubscriptionsProvider)
            .requireValue
            .subscriptions
            .map((s) => s.id),
        ['home'],
      );
      expect(find.text('Home pin'), findsOneWidget);
    },
  );

  testWidgets(
    'manual view keeps move actions with disabled boundaries for folders and their searches',
    (tester) async {
      late String animalsId;
      late String otherId;
      await tester.runAsync(() async {
        await harness.seed([
          pinnedFixture(query: 'cat'),
          pinnedFixture(id: 'dogs', name: 'Dogs', query: 'dog', position: 1),
        ]);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        final animals = await notifier.createSharedFolder('Animals');
        animalsId = animals.id;
        await notifier.movePinToSharedFolder('cats', animals.id);
        await notifier.movePinToSharedFolder('dogs', animals.id);
        otherId = (await notifier.createSharedFolder('Other')).id;
      });
      await harness.pump(tester, const PinnedSearchesPage());

      for (final c in [
        (id: animalsId, moveUp: false, moveDown: true),
        (id: otherId, moveUp: true, moveDown: false),
      ]) {
        await openFolderMenu(tester, c.id);
        expect(actionItem(tester, 'Move up').enabled, c.moveUp);
        expect(actionItem(tester, 'Move down').enabled, c.moveDown);
        await dismissMenu(tester);
      }

      await tester.tap(find.text('Animals'));
      await settle(tester);
      for (final c in [
        (name: 'Cats', moveUp: false, moveDown: true),
        (name: 'Dogs', moveUp: true, moveDown: false),
      ]) {
        final card = find.ancestor(
          of: find.text(c.name),
          matching: find.byType(PinnedSearchCard),
        );
        await tester.tap(
          find.descendant(
            of: card,
            matching: find.byType(PopupMenuButton<PinnedSearchAction>),
          ),
        );
        await settle(tester);
        expect(actionItem(tester, 'Move up').enabled, c.moveUp);
        expect(actionItem(tester, 'Move down').enabled, c.moveDown);
        await dismissMenu(tester);
      }
    },
  );

  testWidgets(
    'sorted views omit move actions from folder cards and searches inside folders',
    (tester) async {
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(previewCount: 1)]);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        folderId = folder.id;
        await notifier.movePinToSharedFolder('cats', folder.id);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      await tester.tap(find.byTooltip('Sort by'));
      await settle(tester);
      await tester.tap(find.text('Updates first'));
      await settle(tester);
      await drain(tester);

      await openFolderMenu(tester, folderId);
      for (final label in ['Move up', 'Move down']) {
        expect(find.text(label), findsNothing);
      }
      await dismissMenu(tester);

      await tester.tap(find.text('Animals'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PinnedSearchCard),
          matching: find.byType(PopupMenuButton<PinnedSearchAction>),
        ),
      );
      await settle(tester);
      for (final label in ['Move up', 'Move down']) {
        expect(find.text(label), findsNothing);
      }
    },
  );

  testWidgets(
    'folder previews use one cached image from the first four populated members in order',
    (tester) async {
      SearchSubscription fixture({
        required String id,
        required int profileId,
        required List<String> thumbnails,
      }) => SearchSubscription(
        id: id,
        profileId: profileId,
        query: id,
        name: id.toUpperCase(),
        position: 0,
        createdAt: checkedAt,
        previews: [
          for (final (index, thumbnail) in thumbnails.indexed)
            SearchPostPreview(
              postId: index,
              postCreatedAt: checkedAt,
              thumbnailUrl: thumbnail,
              sampleUrl: null,
              discoveredAt: checkedAt,
            ),
        ],
        recentPostIdentities: const [],
        unreadCount: 0,
        lastSuccessfulCheckAt: checkedAt,
      );

      final items = [
        fixture(
          id: 'first',
          profileId: 12,
          thumbnails: ['https://images.example/first.jpg'],
        ),
        fixture(id: 'empty', profileId: 12, thumbnails: []),
        fixture(
          id: 'second',
          profileId: 99,
          thumbnails: ['https://images.example/second.jpg'],
        ),
        fixture(
          id: 'third',
          profileId: 12,
          thumbnails: [
            'https://images.example/third.jpg',
            'https://images.example/third-extra.jpg',
          ],
        ),
        fixture(
          id: 'fourth',
          profileId: 99,
          thumbnails: ['https://images.example/fourth.jpg'],
        ),
        fixture(
          id: 'excluded',
          profileId: 12,
          thumbnails: ['https://images.example/excluded.jpg'],
        ),
      ];
      await tester.runAsync(() async {
        await harness.seed(items);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        for (final item in items) {
          await notifier.movePinToSharedFolder(item.id, folder.id);
        }
      });

      await harness.pump(tester, const PinnedSearchesPage());

      final images = tester
          .widgetList<BooruImage>(find.byType(BooruImage))
          .toList();
      expect(images.map((image) => image.imageUrl), [
        'https://images.example/first.jpg',
        'https://images.example/second.jpg',
        'https://images.example/third.jpg',
        'https://images.example/fourth.jpg',
      ]);
      expect(images.map((image) => image.config), [
        testProfile.auth,
        otherTestProfile.auth,
        testProfile.auth,
        otherTestProfile.auth,
      ]);
      for (final image in images) {
        final size = tester.getSize(find.byWidget(image));
        expect(size.width, size.height);
      }
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('folder icon is immediately before the folder name', (
    tester,
  ) async {
    late String folderId;
    await tester.runAsync(() async {
      await harness.container.read(searchSubscriptionsProvider.future);
      folderId =
          (await harness.container
                  .read(searchSubscriptionsProvider.notifier)
                  .createSharedFolder('Animals'))
              .id;
    });

    await harness.pump(tester, const PinnedSearchesPage());

    final card = folderCard(folderId);
    final icon = find.descendant(
      of: card,
      matching: find.byIcon(Symbols.folder),
    );
    final name = find.descendant(of: card, matching: find.text('Animals'));
    expect(icon, findsOneWidget);
    expect(name, findsOneWidget);
    expect(tester.getRect(icon).right, lessThan(tester.getRect(name).left));
    expect(
      tester.getRect(name).left - tester.getRect(icon).right,
      lessThanOrEqualTo(6),
    );
  });

  testWidgets(
    'folder shows the newest cached member post regardless of member and preview order without fetching',
    (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 9, 14, 12)), () async {
        final items = [
          cachedFixture(
            id: 'older',
            postCreatedAts: [
              DateTime.utc(2026, 9, 14, 5),
              DateTime.utc(2026, 9, 14, 9),
            ],
          ),
          cachedFixture(id: 'unknown', postCreatedAts: [null]),
          cachedFixture(
            id: 'newest',
            postCreatedAts: [DateTime.utc(2026, 9, 14, 10)],
          ),
        ];
        await tester.runAsync(() async {
          await harness.seed(items);
          await harness.container.read(searchSubscriptionsProvider.future);
          final notifier = harness.container.read(
            searchSubscriptionsProvider.notifier,
          );
          final folder = await notifier.createSharedFolder('Animals');
          for (final item in items) {
            await notifier.movePinToSharedFolder(item.id, folder.id);
          }
        });

        await harness.pump(tester, const PinnedSearchesPage());

        expect(find.text('Last post: 2 hours ago'), findsOneWidget);
        expect(harness.requests, isEmpty);
      });
    },
  );

  for (final c in [
    (
      name: 'an empty folder',
      hasMember: false,
      label: 'Last post: Not checked',
    ),
    (
      name: 'a cached post without an upload time',
      hasMember: true,
      label: 'Last post: No posts',
    ),
  ]) {
    testWidgets('${c.name} uses the matching search card Last post state', (
      tester,
    ) async {
      late String folderId;
      await tester.runAsync(() async {
        if (c.hasMember) {
          await harness.seed([
            cachedFixture(id: 'unknown', postCreatedAts: [null]),
          ]);
        }
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        final folder = await notifier.createSharedFolder('Animals');
        folderId = folder.id;
        if (c.hasMember) {
          await notifier.movePinToSharedFolder('unknown', folder.id);
        }
      });

      await harness.pump(tester, const PinnedSearchesPage());

      expect(
        find.descendant(
          of: folderCard(folderId),
          matching: find.text(c.label),
        ),
        findsOneWidget,
      );
      expect(harness.requests, isEmpty);
    });
  }

  for (final c in [
    (name: 'normal text', width: 800.0, textScale: 1.0),
    (name: 'a narrow screen with large text', width: 320.0, textScale: 2.0),
  ]) {
    testWidgets(
      'folder and search cards keep compact padding, thumbnails, and accessible actions with ${c.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(c.width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        late String folderId;
        await tester.runAsync(() async {
          await harness.seed([
            pinnedFixture(
              id: 'folder-pin',
              name: 'Folder pin',
              previewCount: 1,
            ),
            pinnedFixture(
              id: 'home',
              name: 'Home pin',
              query: 'Home pin',
              previewCount: 1,
            ),
          ]);
          await harness.container.read(searchSubscriptionsProvider.future);
          final notifier = harness.container.read(
            searchSubscriptionsProvider.notifier,
          );
          final folder = await notifier.createSharedFolder('Animals');
          folderId = folder.id;
          await notifier.movePinToSharedFolder('folder-pin', folder.id);
        });

        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(c.textScale)),
            child: const PinnedSearchesPage(),
          ),
        );

        final folder = folderCard(folderId);
        final search = find.byType(PinnedSearchCard);
        final folderIcon = find.descendant(
          of: folder,
          matching: find.byIcon(Symbols.folder),
        );
        final searchTitle = find.descendant(
          of: search,
          matching: find.text('Home pin'),
        );
        final folderImage = find.descendant(
          of: folder,
          matching: find.byType(BooruImage),
        );
        final searchImage = find.descendant(
          of: search,
          matching: find.byType(BooruImage),
        );
        final folderMenu = find.descendant(
          of: folder,
          matching: find.byType(PopupMenuButton<PinnedSearchAction>),
        );
        final searchMenu = find.descendant(
          of: search,
          matching: find.byType(PopupMenuButton<PinnedSearchAction>),
        );
        final folderItemCount = find.descendant(
          of: folder,
          matching: find.text('1 items'),
        );
        final searchOwner = find.descendant(
          of: search,
          matching: find.text('https://active.example'),
        );
        final folderName = find.descendant(
          of: folder,
          matching: find.text('Animals'),
        );
        final folderBadge = find.descendant(
          of: folder,
          matching: find.text('NEW'),
        );
        final searchBadge = find.descendant(
          of: search,
          matching: find.text('NEW'),
        );
        final folderHeaderRects = [
          folderName,
          folderBadge,
          folderMenu,
        ].map(tester.getRect).toList();
        final searchHeaderRects = [
          searchTitle,
          searchBadge,
          searchMenu,
        ].map(tester.getRect).toList();
        final folderHeaderTop = folderHeaderRects
            .map((rect) => rect.top)
            .reduce((left, right) => left < right ? left : right);
        final folderHeaderBottom = folderHeaderRects
            .map((rect) => rect.bottom)
            .reduce((left, right) => left > right ? left : right);
        final searchHeaderTop = searchHeaderRects
            .map((rect) => rect.top)
            .reduce((left, right) => left < right ? left : right);
        final searchHeaderBottom = searchHeaderRects
            .map((rect) => rect.bottom)
            .reduce((left, right) => left > right ? left : right);

        expect(folder, findsOneWidget);
        expect(search, findsOneWidget);
        expect(folderImage, findsOneWidget);
        expect(searchImage, findsOneWidget);
        expect(
          tester.getRect(folderIcon).left - tester.getRect(folder).left,
          closeTo(12, 1),
        );
        expect(
          tester.getRect(searchTitle).left - tester.getRect(search).left,
          closeTo(12, 1),
        );
        expect(
          tester.getRect(folderImage).left - tester.getRect(folder).left,
          closeTo(13, 1),
        );
        expect(
          tester.getRect(searchImage).left - tester.getRect(search).left,
          closeTo(13, 1),
        );
        expect(
          folderHeaderTop - tester.getRect(folder).top,
          closeTo(8, 1),
        );
        expect(
          searchHeaderTop - tester.getRect(search).top,
          closeTo(8, 1),
        );
        expect(
          tester.getRect(folderImage).top - folderHeaderBottom,
          closeTo(4, 1),
        );
        expect(
          tester.getRect(searchImage).top - searchHeaderBottom,
          closeTo(4, 1),
        );
        expect(
          tester.getRect(folder).bottom -
              tester.getRect(folderItemCount).bottom,
          closeTo(12, 1),
        );
        expect(
          tester.getRect(search).bottom - tester.getRect(searchOwner).bottom,
          closeTo(12, 1),
        );
        for (final menu in [folderMenu, searchMenu]) {
          expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty folders disable refresh on the card and opened page', (
    tester,
  ) async {
    late String folderId;
    await tester.runAsync(() async {
      await harness.container.read(searchSubscriptionsProvider.future);
      folderId =
          (await harness.container
                  .read(searchSubscriptionsProvider.notifier)
                  .createSharedFolder('Empty'))
              .id;
    });

    await harness.pump(tester, const PinnedSearchesPage());
    await openFolderMenu(tester, folderId);
    expect(actionItem(tester, 'Refresh').enabled, isFalse);
    await dismissMenu(tester);

    await harness.pump(tester, PinnedSearchesPage(folderId: folderId));
    await tester.tap(pageOverflow());
    await settle(tester);
    expect(actionItem(tester, 'Refresh Folder').enabled, isFalse);
  });

  testWidgets(
    'unsupported-only folders disable refresh and cannot dispatch from either menu',
    (tester) async {
      harness.dispose();
      harness = PinnedSearchHarness(supported: false);
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        folderId = (await notifier.createSharedFolder('Animals')).id;
        await notifier.movePinToSharedFolder('cats', folderId);
      });

      await harness.pump(tester, const PinnedSearchesPage());
      await openFolderMenu(tester, folderId);
      expect(actionItem(tester, 'Refresh').enabled, isFalse);
      await tester.tap(find.text('Refresh').last);
      await settle(tester);
      expect(harness.requests, isEmpty);
      await dismissMenu(tester);

      await harness.pump(tester, PinnedSearchesPage(folderId: folderId));
      await tester.tap(pageOverflow());
      await settle(tester);
      expect(actionItem(tester, 'Refresh Folder').enabled, isFalse);
      await tester.tap(find.text('Refresh Folder'));
      await settle(tester);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'an active folder refresh disables refresh on the card and opened page',
    (tester) async {
      harness.refreshGate = Completer<void>();
      late String folderId;
      await tester.runAsync(() async {
        await harness.seed([pinnedFixture(query: 'cat')]);
        await harness.container.read(searchSubscriptionsProvider.future);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        folderId = (await notifier.createSharedFolder('Animals')).id;
        await notifier.movePinToSharedFolder('cats', folderId);
      });

      await harness.pump(tester, const PinnedSearchesPage());
      await openFolderMenu(tester, folderId);
      await tester.tap(find.text('Refresh').last);
      await settle(tester);
      for (var i = 0; i < 20 && harness.requests.isEmpty; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(harness.requests, [(profileId: 12, query: 'cat')]);
      await tester.pump();

      await openFolderMenu(tester, folderId);
      expect(actionItem(tester, 'Refresh').enabled, isFalse);
      await dismissMenu(tester);

      await harness.pump(tester, PinnedSearchesPage(folderId: folderId));
      await tester.tap(pageOverflow());
      await settle(tester);
      expect(actionItem(tester, 'Refresh Folder').enabled, isFalse);
      await dismissMenu(tester);

      harness.refreshGate!.complete();
      await settle(tester);
      await drain(tester);
    },
  );

  testWidgets('a missing folder disables refresh on the opened page', (
    tester,
  ) async {
    await harness.pump(
      tester,
      const PinnedSearchesPage(folderId: 'missing-folder'),
    );

    await tester.tap(pageOverflow());
    await settle(tester);
    expect(actionItem(tester, 'Refresh Folder').enabled, isFalse);
  });

  testWidgets('folder cards remain usable on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late String folderId;
    await tester.runAsync(() async {
      await harness.seed([pinnedFixture()]);
      await harness.container.read(searchSubscriptionsProvider.future);
      final notifier = harness.container.read(
        searchSubscriptionsProvider.notifier,
      );
      final folder = await notifier.createSharedFolder(
        'A long folder name that needs more than one line',
      );
      folderId = folder.id;
      await notifier.movePinToSharedFolder('cats', folder.id);
    });

    await harness.pump(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: PinnedSearchesPage(),
      ),
    );

    expect(folderCard(folderId), findsOneWidget);
    expect(
      find.descendant(
        of: folderCard(folderId),
        matching: find.byTooltip('More'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('refreshing a shared folder uses each pin owner', () async {
    final cats = pinnedFixture(query: 'cat');
    final dogs = pinnedFixture(id: 'dogs', profileId: 99, query: 'dog');
    await harness.seed([cats, dogs]);
    final notifier = harness.container.read(
      searchSubscriptionsProvider.notifier,
    );
    await harness.container.read(searchSubscriptionsProvider.future);
    final folder = await notifier.createSharedFolder('Animals');
    await notifier.movePinToSharedFolder(cats.id, folder.id);
    await notifier.movePinToSharedFolder(dogs.id, folder.id);

    await notifier.refreshSharedFolder(folder.id);

    expect(harness.requests, [
      (profileId: 12, query: 'cat'),
      (profileId: 99, query: 'dog'),
    ]);
  });

  testWidgets(
    'opening a folder navigates to its own manually ordered search page',
    (tester) async {
      await tester.runAsync(() async {
        final cats = pinnedFixture(query: 'cat');
        await harness.seed([cats]);
        final notifier = harness.container.read(
          searchSubscriptionsProvider.notifier,
        );
        await harness.container.read(searchSubscriptionsProvider.future);
        final folder = await notifier.createSharedFolder('Animals');
        await notifier.movePinToSharedFolder(cats.id, folder.id);
      });
      await harness.pump(tester, const PinnedSearchesPage());
      expect(find.text('Cats'), findsNothing);
      expect(find.text('Animals'), findsOneWidget);
      await tester.tap(find.text('Animals'));
      await settle(tester);
      expect(find.text('Cats'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(harness.requests, isEmpty);
    },
  );
}
