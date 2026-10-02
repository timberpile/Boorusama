import 'dart:async';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/count/providers.dart';
import 'package:boorusama/core/posts/count/src/post_count_repository.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/search/search/src/routes/params.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/subscriptions/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

import 'subscription_test_utils.dart';

void main() {
  var config = BooruConfig.empty;
  var searchResultCount = 0;
  const query = 'cat  rating:safe';
  late _FailingBox box;
  late SearchSubscriptionRepository repository;
  late SearchPageController controller;
  late ValueNotifier<PostGridController<Post>?> postController;
  late ProviderContainer container;
  late Completer<Either<BooruError, PostResult<Post>>> snapshot;
  var snapshotCalls = 0;

  Future<void> initialize({
    bool supported = true,
    BooruType? booruType,
    int? endpointCount,
    Future<int?> Function()? countFetcher,
    int resultCount = 0,
    bool showListConfiguration = true,
  }) async {
    searchResultCount = resultCount;
    config = switch (booruType) {
      final type? => BooruConfig.defaultConfig(
        booruType: type,
        url: 'https://example.com',
        customDownloadFileNameFormat: null,
      ),
      null => BooruConfig.empty,
    };
    box = _FailingBox();
    repository = HiveSearchSubscriptionRepository(
      box: box,
      organizationBox: MemoryBox<dynamic>(),
    );
    snapshot = Completer();
    snapshotCalls = 0;
    container = ProviderContainer(
      overrides: [
        pinnedSearchTrackingSupportedProvider.overrideWith(
          (ref, config) => supported,
        ),
        initialSettingsBooruConfigProvider.overrideWithValue(config),
        currentReadOnlyBooruConfigProvider.overrideWithValue(config),
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(config.auth),
        currentReadOnlyBooruConfigSearchProvider.overrideWithValue(
          config.search,
        ),
        currentReadOnlyBooruConfigFilterProvider.overrideWithValue(
          config.filter,
        ),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        settingsNotifierProvider.overrideWith(
          () => SettingsNotifier(Settings.defaultSettings),
        ),
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing.copyWith(
            showPostListConfigHeader: showListConfiguration,
          ),
        ),
        booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
        if (endpointCount != null || countFetcher != null)
          postCountRepoProvider.overrideWith(
            (ref, _) => PostCountRepositoryBuilder(
              countTags: (_) =>
                  countFetcher?.call() ?? Future.value(endpointCount),
            ),
          ),
        analyticsProvider.overrideWith((ref) => null),
        blacklistTagsProvider.overrideWith((ref, config) => {}),
        blacklistTagEntriesProvider.overrideWith((ref, config) => {}),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [config]),
        ),
        searchSubscriptionRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
        searchSubscriptionsProvider.overrideWith(
          () => SearchSubscriptionsNotifier(
            refreshService: SearchRefreshService(
              repository: repository,
              resolvePostRepository: (_) => TestSearchPostRepository((_, _, _) {
                snapshotCalls++;
                return snapshot.future;
              }),
              resolveQueryAdapter: (_) =>
                  const DefaultSearchRefreshQueryAdapter(),
              scanner: ChronologicalSearchScanner(),
            ),
          ),
        ),
      ],
    );
    await repository.getAll();
    addTearDown(container.dispose);
  }

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    await container.read(searchSubscriptionsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: SearchPageScaffold<Post>(
                params: const SearchParams(),
                fetcher: (_, _) => TaskEither.of(
                  PostResult(posts: const <Post>[], total: searchResultCount),
                ),
                landingViewBuilder: (_) => const SizedBox.shrink(),
                searchRegionBuilder: (posts, value) {
                  postController = posts;
                  controller = value;
                  return const SizedBox.shrink();
                },
                extraHeaders: (_, _) => [
                  const SliverToBoxAdapter(child: Text('Engine header')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> load(WidgetTester tester, [String value = query]) async {
    controller.skipToResultWithTag(value);
    await tester.pump();
    await tester.runAsync(() => postController.value!.refresh());
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> submit(
    WidgetTester tester,
    String name, {
    bool existing = false,
  }) async {
    await tester.tap(
      find.byTooltip(existing ? 'Manage Pinned Search' : 'Pin Search'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text(existing ? 'Save' : 'Pin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  final layouts = [
    (width: 800.0, textScale: 1.0),
    (width: 320.0, textScale: 1.0),
    (width: 320.0, textScale: 2.0),
    (width: 240.0, textScale: 2.0),
  ];
  final countSources = [
    (type: BooruType.danbooru, source: 'endpoint', endpointCount: 12345),
    (type: BooruType.gelbooru, source: 'search', endpointCount: null),
  ];
  for (final source in countSources) {
    for (final layout in layouts) {
      testWidgets(
        'keeps the ${source.source} result count and search actions on one row at ${layout.width} width and ${layout.textScale}x text',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(layout.width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await initialize(
            booruType: source.type,
            endpointCount: source.endpointCount,
            resultCount: 12345,
            showListConfiguration: false,
          );
          await pump(tester, textScale: layout.textScale);
          await load(tester);
          await tester.runAsync(() async {});
          await tester.pump();
          final count = find.text('12345 Results');
          final pin = find.byTooltip('Pin Search');
          final follow = find.widgetWithText(TextButton, 'Follow');
          expect(count, findsOneWidget);
          expect(pin, findsOneWidget);
          expect(follow, findsOneWidget);
          final countBounds = tester.getRect(count);
          final pinBounds = tester.getRect(pin);
          final followBounds = tester.getRect(follow);
          expect(countBounds.center.dy, closeTo(pinBounds.center.dy, 1));
          expect(followBounds.center.dy, closeTo(pinBounds.center.dy, 1));
          expect(countBounds.right, lessThanOrEqualTo(pinBounds.left));
          expect(pinBounds.right, lessThanOrEqualTo(followBounds.left));
          expect(followBounds.right, lessThanOrEqualTo(layout.width));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  final countStates = [
    (state: 'loading', visible: 'Searching...'),
    (state: 'empty', visible: 'No result'),
    (state: 'unavailable', visible: null),
    (state: 'failed', visible: null),
  ];
  for (final c in countStates) {
    testWidgets('keeps search actions available when the count is ${c.state}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await initialize(
        booruType: BooruType.danbooru,
        showListConfiguration: false,
        countFetcher: () => switch (c.state) {
          'loading' => Completer<int?>().future,
          'empty' => Future.value(0),
          'failed' => Future.error(Exception('Count unavailable')),
          _ => Future.value(),
        },
      );
      await pump(tester, textScale: 2);
      await load(tester);
      await tester.runAsync(() async {});
      await tester.pump();
      if (c.visible case final label?) {
        expect(find.text(label), findsOneWidget);
      } else {
        expect(find.text('Searching...'), findsNothing);
        expect(find.text('No result'), findsNothing);
      }
      final pin = find.byTooltip('Pin Search');
      final follow = find.widgetWithText(TextButton, 'Follow');
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: pin, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.widget<TextButton>(follow).onPressed, isNotNull);
      expect(tester.getCenter(pin).dy, closeTo(tester.getCenter(follow).dy, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps saved and followed searches manageable in the same row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initialize(
      booruType: BooruType.danbooru,
      endpointCount: 12345,
      showListConfiguration: false,
    );
    await repository.create(profileId: config.id, query: query, name: null);
    await repository.saveFeed(
      profileId: config.id,
      name: 'Cats',
      queries: [query],
    );
    await pump(tester, textScale: 2);
    await load(tester);
    await tester.runAsync(() async {});
    await tester.pump();
    final count = find.text('12345 Results');
    final pin = find.byTooltip('Manage Pinned Search');
    final follow = find.widgetWithText(TextButton, 'Following');
    expect(count, findsOneWidget);
    expect(pin, findsOneWidget);
    expect(follow, findsOneWidget);
    expect(tester.getCenter(count).dy, closeTo(tester.getCenter(pin).dy, 1));
    expect(tester.getCenter(follow).dy, closeTo(tester.getCenter(pin).dy, 1));
    await tester.tap(follow);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Cats'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Cats'),
          )
          .value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the header row aligned above unsupported pin feedback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initialize(
      booruType: BooruType.danbooru,
      endpointCount: 12345,
      supported: false,
      showListConfiguration: false,
    );
    await pump(tester, textScale: 2);
    await load(tester);
    await tester.runAsync(() async {});
    await tester.pump();
    await tester.tap(find.byTooltip('Pin Search'));
    await tester.pump();
    final count = find.text('12345 Results');
    final pin = find.byTooltip('Pin Search');
    final follow = find.widgetWithText(TextButton, 'Follow');
    final error = find.text(
      'Pinned searches are not supported for this profile.',
    );
    expect(error, findsOneWidget);
    expect(tester.getCenter(count).dy, closeTo(tester.getCenter(pin).dy, 1));
    expect(tester.getCenter(follow).dy, closeTo(tester.getCenter(pin).dy, 1));
    expect(
      tester.getRect(error).top,
      greaterThanOrEqualTo(tester.getRect(pin).bottom),
    );
    expect(tester.getRect(error).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pinning lists shared folders and saves into a folder containing another owner',
    (tester) async {
      await initialize();
      final other = await repository.create(
        profileId: 99,
        query: 'dog',
        name: 'Dog',
      );
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'shared',
              name: 'Shared animals',
              searchIds: [other.id],
            ),
          ],
          homeSearchIds: const [],
        ),
      );
      await pump(tester);
      await load(tester);
      await tester.tap(find.byTooltip('Pin Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('[Home]'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Shared animals').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Pin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final pin = await repository.findByQuery(config.id, query);
      expect(pin?.profileId, config.id);
      expect((await repository.getOrganization()).folders.single.searchIds, [
        other.id,
        pin!.id,
      ]);
      snapshot.complete(Either.of(const PostResult(posts: <Post>[], total: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'an unsupported pin action explains support without saving or fetching',
    (tester) async {
      await initialize(supported: false);
      await pump(tester);
      await load(tester);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Follow'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Pin Search'));
      await tester.pump();
      expect(
        find.text('Pinned searches are not supported for this profile.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(await repository.getAll(), isEmpty);
      expect(snapshotCalls, 0);
    },
  );

  testWidgets('only a loaded non-empty query exposes the pin action', (
    tester,
  ) async {
    await initialize();
    await pump(tester);
    expect(find.byTooltip('Pin Search'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    await load(tester, '   ');
    expect(find.byTooltip('Pin Search'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    await load(tester);
    expect(find.byTooltip('Pin Search'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Engine header'), findsOneWidget);
  });

  testWidgets(
    'saves the exact current profile and query before the snapshot finishes',
    (tester) async {
      await initialize();
      await repository.create(
        profileId: 99,
        query: query,
        name: 'Other profile',
      );
      await pump(tester);
      await load(tester);
      await submit(tester, '  Cats  ');
      final saved = await repository.findByQuery(config.id, query);
      expect(saved?.name, 'Cats');
      expect(saved?.query, query);
      expect(saved?.lastSuccessfulCheckAt, isNull);
      expect(find.text('Search pinned'), findsNothing);
      expect(find.byTooltip('Manage Pinned Search'), findsOneWidget);
      expect(find.byType(SearchPageScaffold<Post>), findsOneWidget);
      expect(snapshotCalls, 1);
      snapshot.complete(Either.of(const PostResult(posts: <Post>[], total: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        (await repository.findByQuery(config.id, query))?.lastSuccessfulCheckAt,
        isNotNull,
      );
    },
  );

  testWidgets(
    'renames an existing pin without duplicating it or fetching again',
    (tester) async {
      await initialize();
      final saved = await repository.create(
        profileId: config.id,
        query: query,
        name: 'Cats',
      );
      await pump(tester);
      await load(tester);
      await tester.tap(find.byTooltip('Manage Pinned Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Cats',
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect((await repository.getAll()).single.id, saved.id);
      expect((await repository.getAll()).single.name, isNull);
      expect(snapshotCalls, 0);
      expect(find.text('Pinned search updated'), findsNothing);
    },
  );

  for (final c in [
    (destination: 'Home', folderId: null),
    (destination: 'shared folder', folderId: 'shared'),
  ]) {
    testWidgets(
      'saving an existing pin preserves its order in ${c.destination}',
      (tester) async {
        await initialize();
        final saved = await repository.create(
          profileId: config.id,
          query: query,
          name: 'Cats',
        );
        final other = await repository.create(
          profileId: 99,
          query: 'dog',
          name: 'Dogs',
        );
        final organization = SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'shared',
              name: 'Animals',
              searchIds: c.folderId == null ? [] : [saved.id, other.id],
            ),
          ],
          homeSearchIds: c.folderId == null ? [saved.id, other.id] : [],
        );
        await repository.replaceOrganization(organization);
        await pump(tester);
        await load(tester);
        await submit(tester, 'Cats', existing: true);
        expect(await repository.getOrganization(), organization);
        await submit(tester, 'Renamed cats', existing: true);
        expect((await repository.getById(saved.id))?.name, 'Renamed cats');
        expect(await repository.getOrganization(), organization);
        expect(snapshotCalls, 0);
      },
    );
  }

  testWidgets('cancelling leaves the query unpinned and results open', (
    tester,
  ) async {
    await initialize();
    await pump(tester);
    await load(tester);
    await tester.tap(find.byTooltip('Pin Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await repository.getAll(), isEmpty);
    expect(snapshotCalls, 0);
    expect(find.byType(SearchPageScaffold<Post>), findsOneWidget);
  });

  testWidgets(
    'a failed snapshot keeps the unnamed pin and shows separate feedback',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      await submit(tester, '   ');
      expect((await repository.getAll()).single.name, isNull);
      expect(find.text('Search pinned'), findsNothing);
      snapshot.completeError(Exception('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(
          'Search pinned, but its preview could not be loaded. Refresh it later.',
        ),
        findsOneWidget,
      );
      expect((await repository.getAll()).single.lastSuccessfulCheckAt, isNull);
      expect(find.byType(SearchPageScaffold<Post>), findsOneWidget);
    },
  );

  testWidgets(
    'a delayed preview failure stays in its originating search view',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      await submit(tester, 'Cats');
      final navigator = Navigator.of(
        tester.element(find.byType(SearchPageScaffold<Post>)),
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Opened post')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      snapshot.completeError(Exception('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Opened post'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('preview could not be loaded'), findsNothing);
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('preview could not be loaded'),
        findsOneWidget,
      );
      expect((await repository.getAll()).single.name, 'Cats');
    },
  );

  testWidgets(
    'a persistence failure reports failure without starting a snapshot',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      box.failWrites = true;
      await submit(tester, 'Cats');
      expect(await repository.getAll(), isEmpty);
      expect(snapshotCalls, 0);
      expect(
        find.text('Could not save the pinned search. Try again.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Pin Search'), findsOneWidget);
    },
  );
}

class _RepositoryNotifier extends SearchSubscriptionRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final SearchSubscriptionRepository repository;
  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

class _FailingBox extends MemorySubscriptionBox {
  var failWrites = false;
  @override
  Future<void> put(dynamic key, SearchSubscriptionHiveObject value) async {
    if (failWrites) throw StateError('disk full');
    await super.put(key, value);
  }
}
