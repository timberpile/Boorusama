import 'dart:async';
import 'dart:io';

import 'package:booru_clients/shimmie2.dart' as sh;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:boorusama/boorus/shimmie2/clients/providers.dart';
import 'package:boorusama/boorus/shimmie2/favorites/providers.dart';
import 'package:boorusama/boorus/shimmie2/posts/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_sqlite.dart';
import 'package:boorusama/core/bulk_downloads/src/providers/bulk_download_notifier.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_session.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_record.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_session_stats.dart';
import 'package:boorusama/core/downloads/sidecar/data.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/downloads/filename/types.dart';

import '../bulk_downloads/common.dart' as posts;

import 'package:boorusama/foundation/browser/cookie_conversion.dart';
import 'package:boorusama/foundation/browser/types.dart';
import 'package:boorusama/boorus/anime-pictures/client_provider.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/widgets/reboot.dart';

import '../support/boorusama_test_runtime.dart';
import '../bulk_downloads/providers/downloads/common.dart' as bulk;

class _Shimmie extends sh.Shimmie2Client {
  _Shimmie() : super(baseUrl: 'https://example.com/');
  @override
  Future<List<sh.PostDto>> getPosts({
    List<String>? tags,
    int? page,
    int? limit,
    bool useGraphQL = false,
  }) async => [
    sh.PostDto(id: 1, fileUrl: 'https://example.com/1.jpg', ext: 'jpg'),
  ];
}

class _FailCleanupOnce extends DownloadRepositorySqlite {
  _FailCleanupOnce(super.db);
  var attempts = 0;
  @override
  Future<DownloadSessionStats> updateStatisticsAndCleanup(String id) async {
    if (++attempts == 1) throw StateError('injected cleanup failure');
    return super.updateStatisticsAndCleanup(id);
  }
}

class _ConcurrentFileSystem extends IoFileSystem {
  _ConcurrentFileSystem(this.destination);
  final String destination;
  final secondChecks = Completer<void>();
  var destinationChecks = 0;
  @override
  Future<bool> fileExists(String path) async {
    final exists = await super.fileExists(path);
    if (path == destination && ++destinationChecks <= 2) {
      if (destinationChecks == 2) secondChecks.complete();
      await secondChecks.future;
    }
    return exists;
  }
}

void main() {
  test('B06: posts return while favorite lookup remains pending', () async {
    final config = BooruConfig.empty.copyWith(url: 'https://example.com/');
    final auth = config.auth;
    final entered = Completer<void>();
    final release = Completer<List<int>>();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(Settings.defaultSettings),
        listingSettingsForAuthProvider(auth).overrideWithValue(
          Settings.defaultSettings.listing,
        ),
        shimmie2ClientProvider(auth).overrideWithValue(_Shimmie()),
        useGraphQLClientProvider(auth).overrideWith((_) async => false),
        shimmie2CanFavoriteProvider(auth).overrideWith((_) async => true),
        favoriteRepoProvider(auth).overrideWithValue(
          FavoriteRepositoryBuilder<Post>(
            add: (_) async => AddFavoriteStatus.success,
            remove: (_) async => true,
            isFavorited: (_) => false,
            canFavorite: () => true,
            filter: (_) {
              entered.complete();
              return release.future;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    var returned = false;
    final listing = container
        .read(shimmie2PostRepoProvider(config.search))
        .getPosts('', 1)
        .run()
        .then((value) {
          returned = true;
          return value;
        });
    await entered.future;
    try {
      await listing.timeout(const Duration(seconds: 5));
      expect(returned, isTrue);
    } finally {
      release.complete([]);
      await listing;
    }
  });

  test('D02: a failed final cleanup can be retried', () async {
    final db = sqlite3.openInMemory();
    final repo = _FailCleanupOnce(db)..initialize();
    final container = bulk.createBulkDownloadContainer(
      downloadRepository: repo,
      booruBuilder: bulk.MockBooruBuilder(),
    );
    container.read(bulkDownloadProvider);
    await container.pump();
    final task = await repo.createTask(
      bulk.DownloadTestConstants.defaultOptions,
    );
    final session = await repo.createSession(
      task,
      bulk.DownloadTestConstants.defaultAuthConfig,
    );
    await repo.updateSession(session.id, status: DownloadSessionStatus.running);
    final notifier = container.read(bulkDownloadProvider.notifier);
    await expectLater(
      notifier.tryCompleteSession(session.id),
      throwsStateError,
    );
    await notifier.tryCompleteSession(session.id);
    try {
      expect(
        repo.attempts,
        2,
        reason:
            'Persisting completed must not make unfinished cleanup unreachable',
      );
    } finally {
      container.dispose();
      db.close();
    }
  });

  test(
    'D02: SQLite rollback and startup recovery retain final totals',
    () async {
      final db = sqlite3.openInMemory();
      final repo = DownloadRepositorySqlite(db)..initialize();
      final container = bulk.createBulkDownloadContainer(
        downloadRepository: repo,
        booruBuilder: bulk.MockBooruBuilder(),
      );
      final notifier = container.read(bulkDownloadProvider.notifier);
      await notifier.ensureIntegrity();
      addTearDown(() {
        container.dispose();
        db.close();
      });
      final task = await repo.createTask(
        bulk.DownloadTestConstants.defaultOptions,
      );
      final session = await repo.createSession(
        task,
        bulk.DownloadTestConstants.defaultAuthConfig,
      );
      await repo.updateSession(
        session.id,
        status: DownloadSessionStatus.running,
      );
      await repo.createRecord(
        DownloadRecord(
          url: 'https://example.test/a.jpg',
          sessionId: session.id,
          status: DownloadRecordStatus.completed,
          page: 1,
          pageIndex: 0,
          createdAt: DateTime.now(),
          fileName: 'a.jpg',
          fileSize: 12,
        ),
      );
      db.execute(
        "CREATE TRIGGER fail_cleanup BEFORE DELETE ON download_records BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        notifier.tryCompleteSession(session.id),
        throwsA(isA<SqliteException>()),
      );
      expect(
        (await repo.getSession(session.id))!.status,
        DownloadSessionStatus.running,
      );
      expect(await repo.getRecordsCountBySessionId(session.id), 1);
      expect(db.select('SELECT * FROM download_session_statistics'), isEmpty);
      db.execute('DROP TRIGGER fail_cleanup');
      await notifier.ensureIntegrity();
      expect(
        (await repo.getSession(session.id))!.status,
        DownloadSessionStatus.completed,
      );
      expect((await repo.getSession(session.id))!.completedAt, isNotNull);
      expect(await repo.getRecordsCountBySessionId(session.id), 0);
      expect((await repo.getCompletedSessions()).single.stats.totalItems, 1);
      final repeated = await Future.wait([
        repo.updateStatisticsAndCleanup(session.id),
        DownloadRepositorySqlite(db).updateStatisticsAndCleanup(session.id),
      ]);
      expect(repeated.map((stats) => stats.totalSize), [12, 12]);
      expect((await repo.getCompletedSessions()).single.stats.totalItems, 1);
    },
  );

  for (final thrown in [false, true]) {
    test(
      'P04: superseded refresh suppresses stale errors, thrown=$thrown',
      () async {
        final first = Completer<Either<BooruError, PostResult<Post>>>();
        final next = Completer<Either<BooruError, PostResult<Post>>>();
        var calls = 0;
        final controller = PostGridController<Post>(
          fetcher: (_) =>
              TaskEither(() => ++calls == 1 ? first.future : next.future),
          blacklistedTagsFetcher: () async => {},
          mountedChecker: () => true,
          duplicateTracker: PostDuplicateTracker(),
          onError: (_) {},
        );
        addTearDown(controller.dispose);
        final errors = <BooruError?>[];
        controller.errors.addListener(
          () => errors.add(controller.errors.value),
        );
        final a = controller.refresh();
        final b = controller.refresh();
        final obsolete = UnknownError(
          error: StateError('old query'),
          message: 'old query',
        );
        if (thrown) {
          first.completeError(StateError('obsolete'));
        } else {
          first.complete(Either.left(obsolete));
        }
        next.complete(
          Either.right(const PostResult<Post>(posts: [], total: 0)),
        );
        await Future.wait([a, b]);
        expect(errors, isNot(contains(obsolete)));
      },
    );
  }

  test(
    'D01: concurrent conflicting sidecars do not overwrite each other',
    () async {
      final root = await Directory.systemTemp.createTemp('migration-review-');
      addTearDown(() => root.delete(recursive: true));
      final media = File('${root.path}/media.jpg');
      await media.writeAsString('media');
      final writer = SidecarWriter(
        fs: _ConcurrentFileSystem('${media.path}.txt'),
      );
      final outcomes = await Future.wait([
        for (final tag in ['first', 'second'])
          writer
              .write(
                media.path,
                SidecarSnapshot(
                  format: SidecarFormat.tags,
                  tags: [tag],
                  quality: 'original',
                ),
              )
              .then((_) => 'written', onError: (_) => 'conflict'),
      ]);
      expect(
        outcomes.where((value) => value == 'written'),
        hasLength(1),
        reason: 'Only one conflicting metadata snapshot may be published',
      );
    },
  );

  test('P02: malformed optional media host enable value preserves profile', () {
    final profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000001',
      'network': const {'mediaHostOverridesEnabled': 'future-value'},
    });
    expect(profile.networkSettings, isNotNull);
  });

  test(
    'P02: optional profile fallbacks retain UUID and expose import warnings',
    () {
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000002',
        'name': 'Preserved profile',
        'thumbnailActions': const ['download', 'future-action'],
        'network': const {
          'mediaHostOverridesEnabled': 'future-value',
          'mediaHostOverrides': [
            {'from': 'bad/path', 'to': 'cdn.test'},
            {'from': 'source.test', 'to': 'cdn.test'},
          ],
        },
      });
      expect(profile.id, '00000000-0000-4000-8000-000000000002');
      expect(profile.name, 'Preserved profile');
      expect(
        profile.optionWarnings,
        containsAll([
          'profile_thumbnail_actions_fallback',
          'profile_media_rules_fallback',
          'profile_media_enabled_fallback',
        ]),
      );
      expect(profile.networkSettings!.mediaHostOverrides, hasLength(1));
      expect(profile.toJson().toString(), isNot(contains('future-action')));
    },
  );

  test(
    'D07: a missing site ID produces distinct safe fallback names',
    () async {
      final builder = DownloadFileNameBuilder<Post>(
        defaultFileNameFormat: '{id}.{extension}',
        defaultBulkDownloadFileNameFormat: '{id}.{extension}',
        sampleData: [],
        tokenHandlers: [],
      );
      final names = <String>[];
      for (final url in [
        'https://example.com/first/media.jpg',
        'https://example.com/second/media.jpg',
      ]) {
        names.add(
          await builder.generate(
            Settings.defaultSettings,
            const BooruConfigDownload(
              fileNameFormat: null,
              bulkFileNameFormat: null,
              location: null,
            ),
            posts.dummyPost(format: 'jpg'),
            downloadUrl: url,
          ),
        );
      }
      expect(
        names.toSet(),
        hasLength(2),
        reason:
            'Missing site IDs must not collapse unrelated downloads to .jpg',
      );
    },
  );

  test('D05: Anime-Pictures API requests use the shared coordinator', () {
    final config = BooruConfig.empty.copyWith(
      url: 'https://anime-pictures.net',
    );
    final runtime = createTestBoorusamaRuntime();
    final container = ProviderContainer(
      overrides: buildBoorusamaOverrides(
        runtime,
        RebootData(
          config: config,
          configs: [config],
          settings: Settings.defaultSettings,
        ),
      ),
    );
    addTearDown(container.dispose);
    final dio = container.read(animePicturesDioProvider(config.auth));
    expect(dio.httpClientAdapter, isA<CoordinatedHttpClientAdapter>());
    dio.close(force: true);
  });

  test('N05: Android HTTPS cookie export retains a secure transport bound', () {
    // Same shape as WebViewCookieChannel.kt: Android exports no attributes.
    final exported = browserCookiesForRequest(
      uri: Uri.parse('https://example.com/'),
      cookies: [
        const BrowserCookie(
          name: 'cf_clearance',
          value: 'test',
          domain: 'example.com',
          path: '/',
        ),
      ],
      now: DateTime.utc(2026, 10, 16),
    );
    expect(
      exported.single.secure,
      isTrue,
      reason: 'Unknown native attributes must not broaden HTTPS cookies to plaintext HTTP',
    );
  });
}
