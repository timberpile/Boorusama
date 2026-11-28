// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:foundation/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sqlite3/sqlite3.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/client_provider.dart';
import 'package:boorusama/boorus/gelbooru/gelbooru.dart';
import 'package:boorusama/boorus/gelbooru/restoration/widgets.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/bootstrap/boorusama_runtime.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/bulk_downloads/providers.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_sqlite.dart';
import 'package:boorusama/core/bulk_downloads/src/pages/bulk_download_page.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_configs.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_options.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_session.dart';
import 'package:boorusama/core/bulk_downloads/src/widgets/tasks/task_tile.dart';
import 'package:boorusama/core/debug/types.dart';
import 'package:boorusama/core/developer_options/types.dart';
import 'package:boorusama/core/download_manager/src/pages/download_manager_page.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/position/types.dart';
import 'package:boorusama/core/posts/position/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/permissions.dart';

import '../bulk_downloads/providers/downloads/common.dart'
    show AlwaysGrantedPermissionManager, AlwaysExistsDirectoryExistChecker;
import '../support/boorusama_test_runtime.dart';
import '../support/gelbooru_pagination_backend.dart';
import 'support/controlled_download_service.dart';
import 'support/download_event_driver.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets('a 1000 preference uses the Gelbooru stride in the pager', (
    tester,
  ) async {
    final server = GelbooruPaginationBackend(postCount: 150);
    final flow = await _GelbooruFlow.mount(
      tester,
      server,
      postsPerPage: 1000,
      pageMode: PageMode.paginated,
    );
    await flow.waitForPosts(100, firstId: 150);

    final selector = find.byType(PageSelector);
    await flow.harness.pumpUntilFound(tester, selector);
    final next = find.descendant(
      of: selector,
      matching: find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    await tester.ensureVisible(next);
    expect(tester.widget<PageSelector>(selector).itemPerPage, 100);
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);

    await tester.tap(next);
    await flow.waitForPosts(50, firstId: 50);
    expect(flow.controller.page, 2);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    expect(server.requests.last['pid'], 1);
    expect(server.requests.last['limit'], 100);
  });

  testWidgets('Gelbooru position restore uses the same capped stride', (
    tester,
  ) async {
    final server = GelbooruPaginationBackend(postCount: 150);
    final flow = await _GelbooruFlow.mount(
      tester,
      server,
      postsPerPage: 1000,
    );
    await flow.waitForPosts(100, firstId: 150);

    final context = tester.element(flow.grid.first);
    final container = ProviderScope.containerOf(context, listen: false);
    final heldRequest = server.requests.length + 1;
    server.holdOnRequest = heldRequest;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: GelbooruSessionRestorePage(
            snapshot: PaginationSnapshot(
              targetId: 50,
              tags: 'test_tags',
              historicalPage: 2,
              historicalChunkSize: 60,
              timestamp: DateTime.utc(2026, 11, 28),
            ),
          ),
        ),
      ),
    );
    final dialog = find.byType(PageFindingDialog);
    await flow.harness.pumpUntilFound(tester, dialog);
    expect(tester.widget<PageFindingDialog>(dialog).config.userChunkSize, 100);
    server.releaseRequest.complete();
    await flow.waitForPosts(50, firstId: 50);
    expect(flow.controller.page, 2);
  });

  testWidgets(
    'Gelbooru scrolling continues past the depth limit without gaps',
    (tester) async {
      final server = GelbooruPaginationBackend();
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.waitForPosts(60);
      for (var page = 2; page <= 20; page++) {
        await flow.scrollForNextRequest();
        await flow.waitForPosts(page * 60);
      }

      expect(flow.ids, List.generate(1200, (index) => 2505 - index));
      expect(server.tooDeepResponses, 0);
      expect(server.requests.last['tags'], contains('id:<1486'));
    },
  );

  final jumps = [
    (postCount: 2505, page: 18, firstId: 1485, posts: 60),
    (postCount: 2505, page: 35, firstId: 465, posts: 60),
    (postCount: 10000, page: 150, firstId: 1060, posts: 60),
    (postCount: 10000, page: 167, firstId: 40, posts: 40),
  ];
  for (final jump in jumps) {
    testWidgets(
      'Gelbooru opens page ${jump.page} of ${jump.postCount} posts directly',
      (tester) async {
        final server = GelbooruPaginationBackend(postCount: jump.postCount);
        final flow = await _GelbooruFlow.mount(tester, server);
        await flow.waitForPosts(60);
        final before = server.requests.length;
        flow.openSearch(SearchParams(query: 'test_tags', page: jump.page));
        await flow.waitForPosts(jump.posts, firstId: jump.firstId);

        expect(
          flow.ids,
          List.generate(jump.posts, (index) => jump.firstId - index),
        );
        expect(server.tooDeepResponses, 0);
        expect(server.requests.length - before, lessThan(40));
      },
    );
  }

  testWidgets(
    'Gelbooru custom-sort depth errors do not change search ordering',
    (tester) async {
      final server = GelbooruPaginationBackend();
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.waitForPosts(60);
      flow.openSearch(
        const SearchParams(query: 'test_tags sort:score:desc', page: 18),
      );
      await flow.harness.pumpUntilFound(tester, find.text('410'));
      expect(server.requests.last['tags'], contains('sort:score:desc'));
      expect(server.requests.last['tags'], isNot(contains('id:<')));
    },
  );

  testWidgets(
    'Gelbooru bulk download collects 2505 posts and resumes saved records',
    (tester) async {
      final server = GelbooruPaginationBackend();
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.openBulk();
      final discoveryStart = server.requests.length;
      final start = flow.startBulk();
      await flow.harness.pumpUntil(
        tester,
        () => flow.downloads.requests.length == 2505,
        maxPumps: 400,
        description: 'all Gelbooru posts to be discovered and enqueued',
      );
      await start;
      final sessionId = flow.downloads.requests.first.metadata!.group!;
      final records = await flow.repository.getRecordsBySessionId(sessionId);
      expect(records, hasLength(2505));
      expect(records.map((r) => r.url).toSet(), hasLength(2505));
      expect(
        server.requests.skip(discoveryStart).every((r) => r['pid'] == 0),
        isTrue,
      );
      expect((await flow.repository.getSession(sessionId))?.totalPages, 42);
      await flow.harness.pumpUntilFound(
        tester,
        find.byType(BulkDownloadTaskTile),
      );

      // Exercise the actual manager buttons after discovering past the API cap.
      await tester.tap(_taskActions().at(1));
      await flow.harness.pumpUntil(
        tester,
        () => flow.container
            .read(bulkDownloadProvider)
            .sessions
            .any(
              (session) =>
                  session.id == sessionId &&
                  session.session.status == DownloadSessionStatus.paused,
            ),
      );
      expect(
        (await flow.repository.getSession(sessionId))?.status,
        DownloadSessionStatus.paused,
      );
      final requestsBeforeResume = server.requests.length;
      await tester.tap(_taskActions().at(1));
      await flow.harness.pumpUntil(
        tester,
        () => flow.container
            .read(bulkDownloadProvider)
            .sessions
            .any(
              (s) =>
                  s.id == sessionId &&
                  s.session.status == DownloadSessionStatus.running,
            ),
      );
      expect(server.requests, hasLength(requestsBeforeResume));
      await flow.harness.pumpUntil(
        tester,
        () =>
            flow.container
                .read(bulkDownloadProvider)
                .sessions
                .single
                .session
                .currentPage ==
            42,
        maxPumps: 220,
        description: 'resume to finish walking the saved download records',
      );
      await tester.pump(const Duration(milliseconds: 250));
      DownloadEventDriver(flow.container).status(
        flow.downloads.taskAt(0, group: sessionId),
        bg.TaskStatus.running,
      );
      await flow.harness.settle(tester);
      await tester.tap(find.text('test_tags'));
      await flow.harness.pumpUntilFound(
        tester,
        find.byType(DownloadManagerPage),
      );
    },
  );

  testWidgets(
    'Gelbooru bulk continues through filtered, unavailable and existing files',
    (tester) async {
      final server = GelbooruPaginationBackend(
        postCount: 9,
        blacklistedIds: {7, 8, 9},
        unavailableIds: {4, 5, 6},
      );
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.openBulk();
      final start = flow.startBulk(
        perPage: 3,
        blacklistedTags: {'blocked'},
        skipIfExists: true,
        existChecker: _SkipFirstExistingFile(),
      );
      await flow.harness.pumpUntil(
        tester,
        () => flow.downloads.requests.length == 2,
      );
      await start;
      expect(flow.downloads.requests.map((r) => r.url), [
        for (final id in [2, 1]) 'https://gelbooru.example/$id.jpg',
      ]);
      final sessionId = flow.downloads.requests.first.metadata!.group!;
      expect(
        (await flow.repository.getSession(sessionId))?.status,
        DownloadSessionStatus.running,
      );
      await flow.harness.pumpUntilFound(
        tester,
        find.byType(BulkDownloadTaskTile),
      );
    },
  );

  testWidgets(
    'Gelbooru API failure on the first page fails the bulk session',
    (tester) async {
      final server = GelbooruPaginationBackend(postCount: 9);
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.openBulk();
      server.failOnRequest = server.requests.length + 1;
      final start = flow.startBulk(perPage: 3);
      await flow.harness.pumpUntil(
        tester,
        () => flow.container
            .read(bulkDownloadProvider)
            .sessions
            .any(
              (s) => s.session.status == DownloadSessionStatus.failed,
            ),
      );
      await start;
      expect(flow.downloads.requests, isEmpty);
      final sessions = await flow.repository.getActiveSessions();
      expect(sessions.single.session.error, contains('503'));
      expect(
        await flow.repository.getRecordsBySessionId(sessions.single.id),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Gelbooru API failure after the first page keeps the posts already collected',
    (tester) async {
      final server = GelbooruPaginationBackend(postCount: 9);
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.openBulk();
      server.failOnRequest = server.requests.length + 2;
      final start = flow.startBulk(perPage: 3);
      await flow.harness.pumpUntil(
        tester,
        () => flow.container
            .read(bulkDownloadProvider)
            .sessions
            .any((s) => s.session.status == DownloadSessionStatus.failed),
      );
      await start;
      expect(flow.downloads.requests, isEmpty);
      final sessions = await flow.repository.getActiveSessions();
      expect(
        await flow.repository.getRecordsBySessionId(sessions.single.id),
        hasLength(3),
      );
    },
  );

  testWidgets(
    'an empty Gelbooru cursor response with a positive count fails without restarting collection',
    (tester) async {
      final server = GelbooruPaginationBackend(postCount: 9);
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.openBulk();
      final before = server.requests.length;
      server.emptyOnRequest = before + 2;
      final start = flow.startBulk(perPage: 3);
      await flow.harness.pumpUntil(
        tester,
        () => flow.container
            .read(bulkDownloadProvider)
            .sessions
            .any((s) => s.session.status == DownloadSessionStatus.failed),
      );
      await start;

      final sessions = await flow.repository.getActiveSessions();
      expect(
        sessions.single.session.error,
        contains('no posts for a nonempty cursor page'),
      );
      expect(server.requests.skip(before).map((r) => r['tags']), [
        'test_tags',
        'test_tags id:<7',
      ]);
      expect(flow.downloads.requests, isEmpty);
      expect(
        await flow.repository.getRecordsBySessionId(sessions.single.id),
        hasLength(3),
      );
    },
  );

  for (final cancel in [false, true]) {
    testWidgets('ending discovery during page two with cancel=$cancel', (
      tester,
    ) async {
      final server = GelbooruPaginationBackend(postCount: 9);
      final flow = await _GelbooruFlow.mount(tester, server);
      await flow.openBulk();
      final held = server.requests.length + 2;
      server.holdOnRequest = held;
      final run = flow.startBulk(perPage: 3);
      await flow.harness.pumpUntil(
        tester,
        () => server.requests.length == held,
      );
      final session = (await flow.repository.getActiveSessions()).single;
      final notifier = flow.container.read(bulkDownloadProvider.notifier);
      if (cancel) {
        await notifier.cancelSession(session.id);
      } else {
        await notifier.stopDryRun(session.id);
      }
      server.releaseRequest.complete();
      var finished = false;
      final completion = run.then((_) => finished = true);
      await flow.harness.pumpUntil(tester, () => finished);
      await completion;

      final saved = await flow.repository.getSession(session.id);
      expect(
        saved?.status,
        cancel
            ? DownloadSessionStatus.cancelled
            : DownloadSessionStatus.running,
      );
      expect(flow.downloads.requests.map((r) => r.url), [
        if (!cancel)
          for (final id in [9, 8, 7]) 'https://gelbooru.example/$id.jpg',
      ]);
    });
  }

  testWidgets('a Gelbooru error envelope fails discovery after a valid page', (
    tester,
  ) async {
    final server = GelbooruPaginationBackend(postCount: 9);
    final flow = await _GelbooruFlow.mount(tester, server);
    await flow.openBulk();
    server.apiErrorOnRequest = server.requests.length + 2;
    var finished = false;
    final run = flow.startBulk(perPage: 3).then((_) => finished = true);
    await flow.harness.pumpUntil(tester, () => finished);
    await run;
    final saved = (await flow.repository.getActiveSessions()).single;
    expect(saved.session.status, DownloadSessionStatus.failed);
    expect(await flow.repository.getRecordsBySessionId(saved.id), hasLength(3));
    expect(flow.downloads.requests, isEmpty);
  });

  testWidgets('a short Gelbooru cursor page continues from its last raw ID', (
    tester,
  ) async {
    final server = GelbooruPaginationBackend(postCount: 5);
    final flow = await _GelbooruFlow.mount(tester, server);
    await flow.openBulk();
    server.responseLimit = 2;
    var finished = false;
    final run = flow.startBulk(perPage: 5).then((_) => finished = true);
    await flow.harness.pumpUntil(tester, () => finished);
    await run;
    expect(flow.downloads.requests.map((r) => r.url), [
      for (final id in [5, 4, 3, 2, 1]) 'https://gelbooru.example/$id.jpg',
    ]);
  });

  testWidgets('concurrent Gelbooru bulk runs retain independent ID bounds', (
    tester,
  ) async {
    final server = GelbooruPaginationBackend(postCount: 9);
    final flow = await _GelbooruFlow.mount(tester, server);
    await flow.openBulk();
    final starts = Future.wait([
      flow.startBulk(query: 'test_tags id:<5', perPage: 2),
      flow.startBulk(query: 'test_tags id:>=5 sort:id:asc', perPage: 3),
    ]);
    await flow.harness.pumpUntil(
      tester,
      () => flow.downloads.requests.length == 9,
    );
    await starts;
    final bySession = <String, List<String>>{};
    for (final request in flow.downloads.requests) {
      bySession
          .putIfAbsent(request.metadata!.group!, () => [])
          .add(request.url);
    }
    expect(
      bySession.values,
      unorderedEquals([
        [
          for (final id in [4, 3, 2, 1]) 'https://gelbooru.example/$id.jpg',
        ],
        [
          for (final id in [5, 6, 7, 8, 9]) 'https://gelbooru.example/$id.jpg',
        ],
      ]),
    );
    await flow.harness.pumpUntil(
      tester,
      () => find.byType(BulkDownloadTaskTile).evaluate().length == 2,
    );
  });
}

Finder _taskActions() => find.descendant(
  of: find.byType(BulkDownloadTaskTile),
  matching: find.byType(FaIcon),
);

class _GelbooruFlow {
  _GelbooruFlow(
    this.tester,
    this.server,
    this.harness,
    this.repository,
    this.downloads,
  );

  static Future<_GelbooruFlow> mount(
    WidgetTester tester,
    GelbooruPaginationBackend server, {
    int postsPerPage = 60,
    PageMode pageMode = PageMode.infinite,
  }) async {
    const yaml = BooruYamlConfig(
      name: 'gelbooru',
      type: BooruType.gelbooru,
      protocol: NetworkProtocol.https_2_0,
      sites: [SiteConfig(url: 'https://gelbooru.example/')],
    );
    final config = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.gelbooru,
        url: 'https://gelbooru.example/',
        customDownloadFileNameFormat: '{id}',
      ).toJson(),
      'id': '00000000-0000-4000-8000-000000000186',
    });
    final components = createGelbooru();
    final registry = BooruRegistry()
      ..register(
        BooruType.gelbooru,
        BooruComponents(
          parser: DefaultBooruParser(config: yaml),
          createBuilder: components.createBuilder,
          createRepository: components.createRepository,
        ),
      );
    final database = sqlite3.openInMemory();
    final repository = DownloadRepositorySqlite(database)..initialize();
    final downloads = ControlledDownloadService();
    final runtime = createTestBoorusamaRuntime(
      initialState: BoorusamaInitialState(
        initialConfig: config,
        configs: [config],
        settings: Settings.defaultSettings.copyWith(
          currentBooruConfigId: config.id,
          listing: Settings.defaultSettings.listing.copyWith(
            postsPerPage: postsPerPage,
            pageMode: pageMode,
            pageIndicatorPosition: PageIndicatorPosition.top,
          ),
        ),
        developerOptions: DeveloperOptions.defaults,
        logOptions: LogOptions.defaults,
      ),
      booruDb: BooruDb(
        boorus: {BooruType.gelbooru: const BooruScaffold(config: yaml)},
      ),
      booruRegistry: registry,
      downloadService: downloads,
    );
    final harness = HeadlessAppHarness(
      runtime: runtime,
      viewportSize: kMobileViewport,
      additionalOverrides: [
        gelbooruDioProvider.overrideWith((ref, auth) => server.dio),
        internalDownloadRepositoryProvider.overrideWith((ref) => repository),
        mediaPermissionManagerProvider.overrideWithValue(
          AlwaysGrantedPermissionManager(),
        ),
        blacklistTagsProvider.overrideWith((ref, filter) => {}),
        hasPremiumProvider.overrideWithValue(true),
      ],
    );
    addTearDown(() async {
      await harness.teardown(tester);
      server.dio.close();
      database.close();
    });
    await harness.pump(tester);
    final flow = _GelbooruFlow(tester, server, harness, repository, downloads);
    await flow.harness.pumpUntil(tester, () => flow.grid.evaluate().isNotEmpty);
    return flow;
  }

  final WidgetTester tester;
  final GelbooruPaginationBackend server;
  final HeadlessAppHarness harness;
  final DownloadRepositorySqlite repository;
  final ControlledDownloadService downloads;

  Finder get grid => find.byWidgetPredicate((widget) => widget is PostGrid);
  PostGridController<Post> get controller =>
      tester.widget<PostGrid<Post>>(grid.first).controller;
  List<int> get ids => controller.allItems.map((post) => post.id).toList();
  ProviderContainer get container => ProviderScope.containerOf(
    tester.element(find.byType(BulkDownloadPage).first),
  );

  Future<void> waitForPosts(int count, {int? firstId}) => harness.pumpUntil(
    tester,
    () =>
        grid.evaluate().isNotEmpty &&
        ids.length == count &&
        (firstId == null || ids.first == firstId),
    description: '$count Gelbooru posts to load',
  );

  Future<void> scrollForNextRequest() async {
    final before = server.requests.length;
    final scrollable = find
        .descendant(of: grid.first, matching: find.byType(Scrollable))
        .first;
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.fling(scrollable, const Offset(0, -2400), 9000);
      await tester.pump(const Duration(milliseconds: 550));
      if (server.requests.length > before) return;
    }
    throw TestFailure('Scrolling did not request the next Gelbooru page');
  }

  void openSearch(SearchParams params) => unawaited(
    GoRouter.of(tester.element(find.byType(Navigator).first)).push(
      Uri(path: '/search', queryParameters: params.toQueryParams()).toString(),
    ),
  );

  Future<void> openBulk() async {
    await harness.pumpUntil(
      tester,
      () => server.requests.isNotEmpty && !controller.refreshing,
    );
    harness.setViewport(tester, const Size(600, 900));
    unawaited(
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .push('/bulk_downloads'),
    );
    await harness.pumpUntilFound(tester, find.byType(BulkDownloadPage));
    await harness.pumpUntil(
      tester,
      () => container.read(bulkDownloadProvider).ready,
    );
  }

  Future<void> startBulk({
    String query = 'test_tags',
    int perPage = 60,
    Set<String> blacklistedTags = const {},
    bool skipIfExists = false,
    DownloadExistChecker? existChecker,
  }) => container
      .read(bulkDownloadProvider.notifier)
      .downloadFromOptions(
        DownloadOptions(
          path: '/storage/emulated/0/Download',
          skipIfExists: skipIfExists,
          perPage: perPage,
          concurrency: 5,
          tags: SearchTagSet.fromString(query),
        ),
        downloadConfigs: DownloadConfigs(
          downloader: downloads,
          directoryExistChecker: const AlwaysExistsDirectoryExistChecker(),
          headers: const {},
          blacklistedTags: blacklistedTags,
          existChecker: existChecker,
          delayBetweenRequests: Duration.zero,
          delayBetweenDownloads: Duration.zero,
          asyncTokenDelay: Duration.zero,
        ),
      );
}

class _SkipFirstExistingFile implements DownloadExistChecker {
  var _checks = 0;

  @override
  bool exists(String fileName, String path) => _checks++ == 0;
}
