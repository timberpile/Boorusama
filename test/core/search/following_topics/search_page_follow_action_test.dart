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
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_hive_object.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/chronological_search_scanner.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/search_refresh_query_adapter.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_service.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

import 'topic_test_utils.dart';

void main() {
  var config = BooruConfig.empty;
  var searchResultCount = 0;
  const query = 'cat  rating:safe';
  late _FailingBox box;
  late _FailingOrganizationBox organizationBox;
  late FollowingTopicRepository repository;
  late SearchPageController controller;
  late ValueNotifier<PostGridController<Post>?> postController;
  late ProviderContainer container;
  late Completer<Either<BooruError, PostResult<Post>>> snapshot;

  Future<void> initialize({
    bool supported = true,
    BooruType? booruType,
    int? endpointCount,
    Future<int?> Function()? countFetcher,
    int resultCount = 0,
    bool showListConfiguration = true,
  }) async {
    searchResultCount = resultCount;
    final template = switch (booruType) {
      final type? => BooruConfig.defaultConfig(
        booruType: type,
        url: 'https://example.com',
        customDownloadFileNameFormat: null,
      ),
      null => BooruConfig.empty,
    };
    config = BooruConfig.fromJson({
      ...template.toJson(),
      'id': '00000000-0000-4000-8000-00000000000c',
    });
    box = _FailingBox();
    organizationBox = _FailingOrganizationBox();
    repository = HiveFollowingTopicRepository(
      box: box,
      organizationBox: organizationBox,
    );
    snapshot = Completer();
    container = ProviderContainer(
      overrides: [
        followingTopicTrackingSupportedProvider.overrideWith(
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
        followingTopicRepositoryProvider.overrideWith(
          () => _RepositoryNotifier(repository),
        ),
        followingTopicsProvider.overrideWith(
          () => FollowingTopicsNotifier(
            refreshService: SearchRefreshService(
              repository: repository,
              resolvePostRepository: (_) => TestSearchPostRepository((_, _, _) {
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
    await container.read(followingTopicsProvider.future);
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
          final topic = find.byTooltip('Follow');
          expect(count, findsOneWidget);
          expect(topic, findsOneWidget);
          final countBounds = tester.getRect(count);
          final pinBounds = tester.getRect(topic);
          expect(countBounds.center.dy, closeTo(pinBounds.center.dy, 1));
          expect(countBounds.right, lessThanOrEqualTo(pinBounds.left));
          expect(pinBounds.right, lessThanOrEqualTo(layout.width));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  final countStates = [
    (state: 'loading', visible: 'Searching...'),
    (state: 'empty', visible: 'No result'),
    (state: 'unavailable', visible: '7 Results'),
    (state: 'failed', visible: '7 Results'),
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
        resultCount: switch (c.state) {
          'unavailable' || 'failed' => 7,
          _ => 0,
        },
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
      expect(find.text(c.visible), findsOneWidget);
      final topic = find.byTooltip('Follow');
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: topic, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Following opens the destination picker at 240px and 2x text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await initialize(
      booruType: BooruType.danbooru,
      endpointCount: 12345,
      showListConfiguration: false,
    );
    await repository.create(profileId: config.id, query: query, name: null);
    await pump(tester, textScale: 2);
    await load(tester);
    await tester.runAsync(() async {});
    await tester.pump();
    final count = find.text('12345 Results');
    final topic = find.byTooltip('Following');
    expect(count, findsOneWidget);
    expect(topic, findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.getCenter(count).dy, closeTo(tester.getCenter(topic).dy, 1));
    await tester.tap(topic);
    await pumpTransitions(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Manage Topic'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual-only follow remains reachable at narrow width', (
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
    await tester.tap(find.byTooltip('Follow'));
    await pumpTransitions(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(query), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(
      find.textContaining('Automatic tracking is unavailable'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> pumpTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _RepositoryNotifier extends FollowingTopicRepositoryNotifier {
  _RepositoryNotifier(this.repository);
  final FollowingTopicRepository repository;
  @override
  Future<FollowingTopicRepository> build() async => repository;
}

class _FailingBox extends MemorySubscriptionBox {
  var failWrites = false;
  Completer<void>? beforeWrite;
  @override
  Future<void> put(dynamic key, FollowingTopicHiveObject value) async {
    if (failWrites) throw StateError('disk full');
    await beforeWrite?.future;
    await super.put(key, value);
  }
}

class _FailingOrganizationBox extends MemoryBox<dynamic> {
  var failWrites = false;
  var failAfterWrite = false;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failWrites) throw StateError('disk full');
    await super.put(key, value);
    if (failAfterWrite) {
      failAfterWrite = false;
      throw StateError('disk full after write');
    }
  }
}
