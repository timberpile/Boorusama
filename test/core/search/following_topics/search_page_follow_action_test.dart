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
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/follow_topic_dialog.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/follow_topic_folder_picker.dart';
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
import 'package:flutter/services.dart';
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
    snapshotCalls = 0;
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

  Future<void> loadSpecificTags(
    WidgetTester tester,
    List<String> tags,
  ) async {
    controller.skipToResultWithTags(SearchTagSet.fromList(tags));
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
      find.byTooltip(existing ? 'Following' : 'Follow'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(
      find.descendant(
        of: find.byType(FollowTopicDialog),
        matching: find.text(existing ? 'Save' : 'Follow'),
      ),
    );
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

  testWidgets('Following opens topic management at 240px and 2x text', (
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
    expect(find.widgetWithText(TextButton, 'Following'), findsNothing);
    expect(tester.getCenter(count).dy, closeTo(tester.getCenter(topic).dy, 1));
    await tester.tap(topic);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Manage Topic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the header row aligned above unsupported topic feedback', (
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
    await tester.pump();
    final count = find.text('12345 Results');
    final topic = find.byTooltip('Follow');
    final error = find.text(
      'Topics are not supported for this profile.',
    );
    expect(error, findsOneWidget);
    expect(tester.getCenter(count).dy, closeTo(tester.getCenter(topic).dy, 1));
    expect(
      tester.getRect(error).top,
      greaterThanOrEqualTo(tester.getRect(topic).bottom),
    );
    expect(tester.getRect(error).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'destination picker shows Home and direct folders in their existing order',
    (
      tester,
    ) async {
      await initialize();
      await repository.replaceOrganization(
        TopicOrganization(
          folders: [
            TopicFolder(id: 'z', name: 'Zebra', searchIds: const []),
            TopicFolder(id: 'a', name: 'Animals', searchIds: const []),
          ],
          homeSearchIds: const [],
        ),
      );
      await pump(tester);
      await load(tester);
      await tester.tap(find.byTooltip('Follow'));
      await pumpTransitions(tester);
      expect(find.text('Folder'), findsOneWidget);
      await tester.tap(find.byType(FollowTopicFolderPicker));
      await pumpTransitions(tester);
      final home = tester.getCenter(find.text('Home')).dy;
      final zebra = tester.getCenter(find.text('Zebra').last).dy;
      final animals = tester.getCenter(find.text('Animals').last).dy;
      expect(home, lessThan(zebra));
      expect(find.text('Create folder'), findsOneWidget);
      expect(zebra, lessThan(animals));
    },
  );

  for (final c in [(width: 800.0, scale: 1.0), (width: 360.0, scale: 2.0)]) {
    testWidgets(
      'the destination has form spacing at ${c.width}px and ${c.scale}x text',
      (tester) async {
        tester.view.physicalSize = Size(c.width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await initialize();
        await pump(tester, textScale: c.scale);
        await load(tester);
        await tester.tap(find.byTooltip('Follow'));
        await pumpTransitions(tester);
        final name = tester.getRect(find.byType(TextField));
        final destination = tester.getRect(
          find.byType(FollowTopicFolderPicker),
        );
        expect(destination.top - name.bottom, greaterThanOrEqualTo(16));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FollowTopicFolderPicker));
        await pumpTransitions(tester);
        await tester.tap(find.text('Create folder'));
        await pumpTransitions(tester);
        expect(find.text('Create folder'), findsNothing);
        await tester.tap(
          find.descendant(
            of: find.byType(FollowTopicDialog),
            matching: find.text('Follow'),
          ),
        );
        await pumpTransitions(tester);
        expect(find.text('Create folder'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel').last);
        await pumpTransitions(tester);
        expect(find.text('[New]'), findsOneWidget);
        await tester.tap(find.byType(FollowTopicFolderPicker));
        await pumpTransitions(tester);
        await tester.tap(find.text('Home'));
        await pumpTransitions(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Select'));
        await pumpTransitions(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(FollowTopicDialog),
            matching: find.text('Follow'),
          ),
        );
        await pumpTransitions(tester);
        expect((await repository.getAll()).single.query, query);
        snapshot.complete(
          Either.of(const PostResult(posts: <Post>[], total: 0)),
        );
        await pumpTransitions(tester);
      },
    );
  }

  testWidgets(
    'Pin opens a stacked folder dialog and accepting saves its member',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester);
      expect(find.text('Create folder'), findsNothing);
      final pinDialog = tester.state(find.byType(FollowTopicDialog));
      await tester.tap(
        find.descendant(
          of: find.byType(FollowTopicDialog),
          matching: find.text('Follow'),
        ),
      );
      await pumpTransitions(tester);
      expect(find.text('Create folder'), findsOneWidget);
      expect(pinDialog.mounted, isTrue);
      expect((await repository.getOrganization()).folders, isEmpty);
      await acceptFolder(tester, '  Animals  ');
      expect(find.byType(FollowTopicDialog), findsNothing);
      final topic = (await repository.getAll()).single;
      final folder = (await repository.getOrganization()).folders.single;
      expect(folder.name, 'Animals');
      expect(folder.searchIds, [topic.id]);
      expect((await repository.getOrganization()).homeSearchIds, isEmpty);
      expect(snapshotCalls, 1);
      snapshot.complete(Either.of(const PostResult(posts: <Post>[], total: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  for (final c in [
    (dialog: 'folder name', cancelName: true),
    (dialog: 'topic', cancelName: false),
  ]) {
    testWidgets(
      'canceling the ${c.dialog} dialog leaves no folder or topic',
      (tester) async {
        await initialize();
        await pump(tester);
        await load(tester);
        await chooseNewFolder(tester);
        await tester.enterText(find.byType(TextField), 'My cats');
        if (c.cancelName) {
          final pinDialog = tester.state(find.byType(FollowTopicDialog));
          await tester.tap(
            find.descendant(
              of: find.byType(FollowTopicDialog),
              matching: find.text('Follow'),
            ),
          );
          await pumpTransitions(tester);
          await tester.enterText(find.byType(TextField).last, 'Animals');
          await tester.tap(find.text('Cancel').last);
          await pumpTransitions(tester);
          expect(tester.state(find.byType(FollowTopicDialog)), same(pinDialog));
          expect(find.text('[New]'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'My cats',
          );
          expect(await repository.getAll(), isEmpty);
          expect((await repository.getOrganization()).folders, isEmpty);
        }
        await tester.tap(find.text('Cancel'));
        await pumpTransitions(tester);
        expect((await repository.getOrganization()).folders, isEmpty);
        expect(await repository.getAll(), isEmpty);
        expect(snapshotCalls, 0);
      },
    );
  }

  testWidgets(
    'tapping outside the idle topic form still cancels without writes',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester);
      await tester.tapAt(const Offset(5, 5));
      await pumpTransitions(tester);
      expect(find.byType(FollowTopicDialog), findsNothing);
      expect(await repository.getAll(), isEmpty);
      expect((await repository.getOrganization()).folders, isEmpty);
    },
  );

  testWidgets('an empty new folder name cannot be accepted', (tester) async {
    await initialize();
    await pump(tester);
    await load(tester);
    await chooseNewFolder(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FollowTopicDialog),
        matching: find.text('Follow'),
      ),
    );
    await pumpTransitions(tester);
    await tester.enterText(find.byType(TextField).last, '   ');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    expect((await repository.getOrganization()).folders, isEmpty);
    await tester.tap(find.text('Cancel').last);
    await pumpTransitions(tester);
    await tester.tap(find.text('Cancel'));
    await pumpTransitions(tester);
  });

  for (final action in ['outside tap', 'back', 'escape']) {
    testWidgets(
      'an in-flight folder save cannot dismiss with $action or resubmit the topic form',
      (tester) async {
        await initialize();
        await pump(tester);
        await load(tester);
        await chooseNewFolder(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(FollowTopicDialog),
            matching: find.text('Follow'),
          ),
        );
        await pumpTransitions(tester);
        final write = Completer<void>();
        addTearDown(() {
          if (!write.isCompleted) write.complete();
        });
        box.beforeWrite = write;
        await acceptFolder(tester, 'Animals');
        expect(find.byType(FollowTopicDialog), findsOneWidget);
        switch (action) {
          case 'outside tap':
            await tester.tapAt(const Offset(5, 5));
          case 'back':
            await tester.binding.handlePopRoute();
          case 'escape':
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await pumpTransitions(tester);
        expect(find.byType(FollowTopicDialog), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: find.byType(FollowTopicDialog),
                  matching: find.widgetWithText(FilledButton, 'Follow'),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(box.values, isEmpty);
        write.complete();
        await pumpTransitions(tester);
        final topic = (await repository.getAll()).single;
        expect((await repository.getOrganization()).folders.single.searchIds, [
          topic.id,
        ]);
        expect(find.byType(FollowTopicDialog), findsNothing);
        snapshot.complete(
          Either.of(const PostResult(posts: <Post>[], total: 0)),
        );
        await pumpTransitions(tester);
      },
    );
  }

  testWidgets(
    'a folder created while its name dialog is open prevents a duplicate',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(FollowTopicDialog),
          matching: find.text('Follow'),
        ),
      );
      await pumpTransitions(tester);
      await container
          .read(followingTopicsProvider.notifier)
          .createSharedFolder('ANIMALS');
      await acceptFolder(tester, 'Animals');
      expect(await repository.getAll(), isEmpty);
      expect(
        (await repository.getOrganization()).folders.single.name,
        'ANIMALS',
      );
      expect(find.byType(FollowTopicDialog), findsOneWidget);
      expect(find.text('[New]'), findsOneWidget);
      expect(
        find.text('Could not save the topic. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a new-folder preview failure keeps the saved folder and topic', (
    tester,
  ) async {
    await initialize();
    await pump(tester);
    await load(tester);
    await chooseNewFolder(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FollowTopicDialog),
        matching: find.text('Follow'),
      ),
    );
    await pumpTransitions(tester);
    await acceptFolder(tester, 'Animals');
    final topic = (await repository.getAll()).single;
    snapshot.completeError(Exception('offline'));
    await pumpTransitions(tester);
    await tester.pump(const Duration(seconds: 5));
    await pumpTransitions(tester);
    expect((await repository.getAll()).single.id, topic.id);
    expect((await repository.getOrganization()).folders.single.searchIds, [
      topic.id,
    ]);
    expect(
      find.text(
        'Topic followed, but its preview could not be loaded. Refresh it later.',
      ),
      findsOneWidget,
    );
  });

  for (final c in [
    (
      failure: 'duplicate name',
      duplicate: true,
      failPin: false,
      failFolder: false,
      failAfterWrite: false,
    ),
    (
      failure: 'topic storage',
      duplicate: false,
      failPin: true,
      failFolder: false,
      failAfterWrite: false,
    ),
    (
      failure: 'folder storage',
      duplicate: false,
      failPin: false,
      failFolder: true,
      failAfterWrite: false,
    ),
    (
      failure: 'folder storage after write',
      duplicate: false,
      failPin: false,
      failFolder: false,
      failAfterWrite: true,
    ),
  ]) {
    testWidgets('${c.failure} failure leaves no new folder or topic', (
      tester,
    ) async {
      await initialize();
      if (c.duplicate) {
        await repository.replaceOrganization(
          TopicOrganization(
            folders: [
              TopicFolder(
                id: 'existing',
                name: 'ANIMALS',
                searchIds: const [],
              ),
            ],
            homeSearchIds: const [],
          ),
        );
      }
      final before = await repository.getOrganization();
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester);
      box.failWrites = c.failPin;
      organizationBox.failWrites = c.failFolder;
      organizationBox.failAfterWrite = c.failAfterWrite;
      await tester.tap(
        find.descendant(
          of: find.byType(FollowTopicDialog),
          matching: find.text('Follow'),
        ),
      );
      await pumpTransitions(tester);
      await acceptFolder(tester, 'Animals');
      expect(find.byType(FollowTopicDialog), findsOneWidget);
      expect(find.text('[New]'), findsOneWidget);
      expect(await repository.getAll(), isEmpty);
      expect(await repository.getOrganization(), before);
      expect(snapshotCalls, 0);
      expect(
        find.text('Could not save the topic. Try again.'),
        findsOneWidget,
      );
      box.failWrites = false;
      organizationBox.failWrites = false;
      await tester.tap(find.byType(FollowTopicFolderPicker));
      await pumpTransitions(tester);
      await tester.tap(find.text('Home'));
      await pumpTransitions(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Select'));
      await pumpTransitions(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(FollowTopicDialog),
          matching: find.text('Follow'),
        ),
      );
      await pumpTransitions(tester);
      final topic = (await repository.getAll()).single;
      expect((await repository.getOrganization()).homeSearchIds, [topic.id]);
      expect((await repository.getOrganization()).folders, before.folders);
      snapshot.complete(Either.of(const PostResult(posts: <Post>[], total: 0)));
      await pumpTransitions(tester);
    });
  }

  testWidgets('changing a draft destination back to Home creates no folder', (
    tester,
  ) async {
    await initialize();
    await pump(tester);
    await load(tester);
    await chooseNewFolder(tester);
    await tester.tap(find.byType(FollowTopicFolderPicker));
    await pumpTransitions(tester);
    await tester.tap(find.text('Home'));
    await pumpTransitions(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Select'));
    await pumpTransitions(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FollowTopicDialog),
        matching: find.text('Follow'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final topic = (await repository.getAll()).single;
    final organization = await repository.getOrganization();
    expect(organization.folders, isEmpty);
    expect(organization.homeSearchIds, [topic.id]);
    snapshot.complete(Either.of(const PostResult(posts: <Post>[], total: 0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'saving an existing topic in a new folder retains its identity without another preview',
    (tester) async {
      await initialize();
      final topic = await repository.create(
        profileId: config.id,
        query: query,
        name: 'Cats',
      );
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester, existing: true);
      await tester.tap(find.text('Save'));
      await pumpTransitions(tester);
      await acceptFolder(tester, 'Animals');
      expect((await repository.getAll()).single.id, topic.id);
      expect((await repository.getOrganization()).folders.single.searchIds, [
        topic.id,
      ]);
      expect(snapshotCalls, 0);
    },
  );

  testWidgets(
    'a deleted existing topic is not recreated when its draft folder is saved',
    (tester) async {
      await initialize();
      final topic = await repository.create(
        profileId: config.id,
        query: query,
        name: 'Cats',
      );
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester, existing: true);
      await tester.tap(find.text('Save'));
      await pumpTransitions(tester);
      await container.read(followingTopicsProvider.notifier).delete(topic.id);
      await acceptFolder(tester, 'Animals');
      expect(await repository.getAll(), isEmpty);
      expect((await repository.getOrganization()).folders, isEmpty);
      expect(snapshotCalls, 0);
      expect(
        find.text('Could not save the topic. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a failed new-folder save restores an existing topic and its original destination',
    (tester) async {
      await initialize();
      final topic = await repository.create(
        profileId: config.id,
        query: query,
        name: 'Cats',
      );
      await repository.replaceOrganization(
        TopicOrganization(
          folders: [
            TopicFolder(
              id: 'old',
              name: 'Original',
              searchIds: [topic.id],
            ),
          ],
          homeSearchIds: const [],
        ),
      );
      final before = await repository.getOrganization();
      await pump(tester);
      await load(tester);
      await chooseNewFolder(tester, existing: true);
      await tester.enterText(find.byType(TextField), 'Renamed cats');
      organizationBox.failAfterWrite = true;
      await tester.tap(find.text('Save'));
      await pumpTransitions(tester);
      await acceptFolder(tester, 'Animals');
      expect((await repository.getAll()).single, topic);
      expect(await repository.getOrganization(), before);
      expect(snapshotCalls, 0);
      expect(
        find.text('Could not save the topic. Try again.'),
        findsOneWidget,
      );
    },
  );

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'editing preserves' : 'followingOperation saves'} a deeply nested destination',
      (tester) async {
        await initialize();
        final original = editing
            ? await repository.create(
                profileId: config.id,
                query: query,
                name: 'Cats',
              )
            : null;
        await repository.replaceOrganization(
          TopicOrganization(
            folders: [
              TopicFolder(id: 'root', name: 'Artists'),
              TopicFolder(id: 'child', name: 'Cookie', parentId: 'root'),
              TopicFolder(
                id: 'deep',
                name: 'Deep',
                parentId: 'child',
                searchIds: [if (original != null) original.id],
              ),
            ],
          ),
        );
        await pump(tester);
        await load(tester);
        await tester.tap(
          find.byTooltip(editing ? 'Following' : 'Follow'),
        );
        await pumpTransitions(tester);
        await tester.tap(find.byType(FollowTopicFolderPicker));
        await pumpTransitions(tester);
        if (editing) {
          expect(find.text('Deep'), findsNWidgets(2));
          expect(find.widgetWithText(ListTile, 'Artists'), findsNothing);
        } else {
          for (final name in ['Artists', 'Cookie', 'Deep']) {
            await tester.tap(find.widgetWithText(ListTile, name));
            await pumpTransitions(tester);
          }
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Select'));
        await pumpTransitions(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(FollowTopicDialog),
            matching: find.text(editing ? 'Save' : 'Follow'),
          ),
        );
        await pumpTransitions(tester);
        final topic = (await repository.getAll()).single;
        expect(topic.query, query);
        expect(
          (await repository.getOrganization()).folders
              .singleWhere((f) => f.id == 'deep')
              .searchIds,
          [topic.id],
        );
        if (editing) {
          expect(topic.id, original!.id);
          expect(snapshotCalls, 0);
        } else {
          snapshot.complete(
            Either.of(const PostResult(posts: <Post>[], total: 0)),
          );
          await pumpTransitions(tester);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'followingOperation lists shared folders and saves into a folder containing another owner',
    (tester) async {
      await initialize();
      final other = await repository.create(
        profileId: '00000000-0000-4000-8000-000000000063',
        query: 'dog',
        name: 'Dog',
      );
      await repository.replaceOrganization(
        TopicOrganization(
          folders: [
            TopicFolder(
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
      await tester.tap(find.byTooltip('Follow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('[Home]'), findsOneWidget);
      await tester.tap(find.byType(FollowTopicFolderPicker));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Shared animals').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(FilledButton, 'Select'));
      await pumpTransitions(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(FollowTopicDialog),
          matching: find.text('Follow'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final topic = await repository.findByQuery(config.id, query);
      expect(topic?.profileId, config.id);
      expect((await repository.getOrganization()).folders.single.searchIds, [
        other.id,
        topic!.id,
      ]);
      snapshot.complete(Either.of(const PostResult(posts: <Post>[], total: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'an unsupported topic action explains support without saving or fetching',
    (tester) async {
      await initialize(supported: false);
      await pump(tester);
      await load(tester);
      await tester.tap(find.byTooltip('Follow'));
      await tester.pump();
      expect(
        find.text('Topics are not supported for this profile.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(await repository.getAll(), isEmpty);
      expect(snapshotCalls, 0);
    },
  );

  testWidgets('only a loaded non-empty query exposes the topic action', (
    tester,
  ) async {
    await initialize();
    await pump(tester);
    expect(find.byTooltip('Follow'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FollowTopicDialog),
        matching: find.text('Follow'),
      ),
      findsNothing,
    );
    await load(tester, '   ');
    expect(find.byTooltip('Follow'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FollowTopicDialog),
        matching: find.text('Follow'),
      ),
      findsNothing,
    );
    await load(tester);
    expect(find.byTooltip('Follow'), findsOneWidget);
    expect(find.text('Engine header'), findsOneWidget);
  });

  testWidgets(
    'saves the exact current profile and query before the snapshot finishes',
    (tester) async {
      await initialize();
      await repository.create(
        profileId: '00000000-0000-4000-8000-000000000063',
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
      expect(find.text('Topic followed'), findsNothing);
      expect(find.byTooltip('Following'), findsOneWidget);
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
    'followingOperation specific tags preserves their structure beside the canonical query',
    (tester) async {
      await initialize();
      await pump(tester);
      await loadSpecificTags(tester, const ['cat', 'rating:safe']);

      await submit(tester, 'Cats');

      final saved = (await repository.getAll()).single;
      expect(saved.query, 'cat rating:safe');
      expect(
        saved.queryStructure,
        SearchQueryStructure.typedTags(const ['cat', 'rating:safe']),
      );
      snapshot.complete(Either.of(const PostResult(posts: [], total: 0)));
      await tester.pump();
    },
  );

  testWidgets('followingOperation a mixed query keeps the raw-query fallback', (
    tester,
  ) async {
    await initialize();
    await pump(tester);
    controller.skipToResultWithTags(SearchTagSet.fromList(const ['cat']));
    controller.tagsController.addTag(
      const TagSearchItem.raw(tag: 'rating:safe order:score'),
    );
    controller.search();
    await tester.pump();
    await tester.runAsync(() => postController.value!.refresh());
    await tester.pump(const Duration(milliseconds: 500));

    await submit(tester, 'Mixed');

    final saved = (await repository.getAll()).single;
    expect(saved.query, 'cat rating:safe order:score');
    expect(saved.queryStructure, isNull);
    snapshot.complete(Either.of(const PostResult(posts: [], total: 0)));
    await tester.pump();
  });

  testWidgets(
    'renames an existing topic without duplicating it or fetching again',
    (tester) async {
      await initialize();
      final saved = await repository.create(
        profileId: config.id,
        query: query,
        name: 'Cats',
      );
      await pump(tester);
      await load(tester);
      await tester.tap(find.byTooltip('Following'));
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
      expect(find.text('Topic updated'), findsNothing);
    },
  );

  for (final c in [
    (destination: 'Home', folderId: null),
    (destination: 'shared folder', folderId: 'shared'),
  ]) {
    testWidgets(
      'saving an existing topic preserves its order in ${c.destination}',
      (tester) async {
        await initialize();
        final saved = await repository.create(
          profileId: config.id,
          query: query,
          name: 'Cats',
        );
        final other = await repository.create(
          profileId: '00000000-0000-4000-8000-000000000063',
          query: 'dog',
          name: 'Dogs',
        );
        final organization = TopicOrganization(
          folders: [
            TopicFolder(
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
    await tester.tap(find.byTooltip('Follow'));
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
    'a failed snapshot keeps the unnamed topic and shows separate feedback',
    (tester) async {
      await initialize();
      await pump(tester);
      await load(tester);
      await submit(tester, '   ');
      expect((await repository.getAll()).single.name, isNull);
      expect(find.text('Topic followed'), findsNothing);
      snapshot.completeError(Exception('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(
          'Topic followed, but its preview could not be loaded. Refresh it later.',
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
        find.text('Could not save the topic. Try again.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Follow'), findsOneWidget);
    },
  );
}

Future<void> chooseNewFolder(
  WidgetTester tester, {
  bool existing = false,
}) async {
  await tester.tap(
    find.byTooltip(existing ? 'Following' : 'Follow'),
  );
  await pumpTransitions(tester);
  expect(find.text('Create folder'), findsNothing);
  await tester.tap(find.byType(FollowTopicFolderPicker));
  await pumpTransitions(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Home'));
  await pumpTransitions(tester);
  await tester.tap(find.text('Create folder'));
  await pumpTransitions(tester);
}

Future<void> acceptFolder(
  WidgetTester tester,
  String name,
) async {
  await tester.enterText(find.byType(TextField).last, name);
  await tester.pump();
  await tester.tap(find.text('Save').last);
  await pumpTransitions(tester);
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
