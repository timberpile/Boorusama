// Dart imports:
import 'dart:convert';
import 'dart:typed_data';

// Package imports:
import 'package:booru_clients/anime_pictures.dart';
import 'package:booru_clients/zerochan.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

// Project imports:
import 'package:boorusama/boorus/anime-pictures/downloads/file_url_extractor.dart';
import 'package:boorusama/boorus/e621/downloads/providers.dart';
import 'package:boorusama/boorus/e621/posts/types.dart';
import 'package:boorusama/boorus/zerochan/downloads/file_url_extractor.dart';
import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/bulk_downloads/src/data/providers.dart';
import 'package:boorusama/core/bulk_downloads/src/data/repo_sqlite.dart';
import 'package:boorusama/core/bulk_downloads/src/providers/dry_run.dart';
import 'package:boorusama/core/bulk_downloads/src/providers/dry_run_state.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_configs.dart';
import 'package:boorusama/core/bulk_downloads/src/types/download_options.dart'
    as bulk;
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/reboot.dart';

import '../application/support/fake_booru_backend.dart';
import '../bulk_downloads/common.dart';
import '../bulk_downloads/providers/downloads/common.dart'
    show DummyPostRepository;
import '../support/boorusama_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fixture in _fixtures) {
    for (final single in [true, false]) {
      test('${single ? 'single' : 'bulk'} ${fixture.name}', () async {
        final selection = fixture.create();
        final backend = FakeBooruBackend();
        final downloads = MemoryDownloadService();
        final database = sqlite3.openInMemory();
        final repository = DownloadRepositorySqlite(database)..initialize();
        final runtime = backend.createRuntime(
          settings: Settings.defaultSettings.copyWith(
            downloadSidecarFormat: SidecarFormat.json,
            downloadQuality: DownloadQuality.preview,
            downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
          ),
          downloadService: downloads,
        );
        final initial = runtime.initialState;
        final container = ProviderContainer(
          overrides: [
            ...buildBoorusamaOverrides(
              runtime,
              RebootData(
                config: initial.initialConfig,
                configs: initial.configs,
                settings: initial.settings,
              ),
            ),
            internalDownloadRepositoryProvider.overrideWith(
              (_) => repository,
            ),
            postRepoProvider.overrideWith(
              (_, _) => _OnePageRepository(selection.post),
            ),
            downloadFileUrlExtractorProvider.overrideWith(
              (_, _) => selection.extractor,
            ),
          ],
        );
        addTearDown(() {
          container.dispose();
          database.close();
        });

        late String url;
        late String fileName;
        late SidecarSnapshot? sidecar;
        Map<String, String>? headers;
        if (single) {
          final params = container.read(
            downloadNotifierParamsProvider((
              backend.config.auth,
              backend.config.download,
            )),
          );
          await container
              .read(downloadNotifierProvider(params).notifier)
              .download(selection.post, quality: selection.requestedQuality);
          expect(downloads.requests, hasLength(1));
          final request = downloads.requests.single;
          url = request.url;
          fileName = request.filename;
          sidecar = request.sidecar;
          headers = request.headers;
        } else {
          final task = await repository.createTask(
            bulk.DownloadOptions(
              path: '/downloads',
              skipIfExists: false,
              perPage: 1,
              concurrency: 1,
              tags: SearchTagSet.fromList(const ['cat']),
              quality: selection.requestedQuality,
              sidecarFormat: SidecarFormat.json,
            ),
          );
          final session = await repository.createSession(
            task,
            backend.config.auth,
          );
          await container
              .read(dryRunNotifierProvider(session.id).notifier)
              .start(
                session,
                task,
                CancelToken(),
                const DownloadConfigs(
                  headers: {},
                  blacklistedTags: {},
                  delayBetweenRequests: Duration.zero,
                ),
                shouldContinue: () async => true,
                onPageProgress: (_) async {},
              );
          final state = await container.read(
            dryRunNotifierProvider(session.id).future,
          );
          expect(
            state.status,
            isA<DryRunStatusCompleted>(),
            reason: state.error,
          );
          expect(state.allRecords, hasLength(1));
          final record = state.allRecords.single;
          url = record.url;
          fileName = record.fileName;
          sidecar = record.sidecar;
          headers = record.headers;
        }

        // The literal URL and quality are independent fixture expectations;
        // exercising only a fake extractor's quality field would miss fallback.
        expect(url, selection.expectedUrl);
        expect(sidecar, isNotNull);
        expect(sidecar!.quality, selection.expectedQuality);
        if (selection.expectedQuality != 'original') {
          expect(fileName, contains('_${selection.expectedQuality}'));
        }
        if (selection.expectedCookie case final cookie?) {
          expect(headers?['cookie'], cookie);
        }
      });
    }
  }
}

class _OnePageRepository extends DummyPostRepository {
  _OnePageRepository(this.post);

  final Post post;

  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(
    PostResult(posts: page == 1 ? [post] : const [], total: 1),
  );
}

typedef _Selection = ({
  DownloadFileUrlExtractor extractor,
  Post post,
  String requestedQuality,
  String expectedUrl,
  String expectedQuality,
  String? expectedCookie,
});

final _fixtures = <({String name, _Selection Function() create})>[
  (
    name: 'default Original falls back to Sample',
    create: () => (
      extractor: const UrlInsidePostExtractor(),
      post: TestPost(
        id: 101,
        tags: const {'cat'},
        sampleImageUrl: 'https://media.test/sample.jpg',
        thumbnailImageUrl: 'https://media.test/preview.jpg',
      ),
      requestedQuality: 'original',
      expectedUrl: 'https://media.test/sample.jpg',
      expectedQuality: 'sample',
      expectedCookie: null,
    ),
  ),
  for (final requested in ['original', 'sample'])
    (
      name: 'default $requested falls back to Preview',
      create: () => (
        extractor: const UrlInsidePostExtractor(),
        post: TestPost(
          id: 101,
          tags: const {'cat'},
          thumbnailImageUrl: 'https://media.test/preview.jpg',
        ),
        requestedQuality: requested,
        expectedUrl: 'https://media.test/preview.jpg',
        expectedQuality: 'preview',
        expectedCookie: null,
      ),
    ),
  (
    name: 'default ambiguous video fallback is Custom',
    create: () => (
      extractor: const UrlInsidePostExtractor(),
      post: dummyPost(
        id: 101,
        tags: const {'cat'},
        format: '.webm',
        videoUrl: 'https://media.test/unspecified.webm',
      ),
      requestedQuality: 'original',
      expectedUrl: 'https://media.test/unspecified.webm',
      expectedQuality: 'custom',
      expectedCookie: null,
    ),
  ),
  (
    name: 'Zerochan Sample falls back to actual Original',
    create: () {
      final dio = Dio(BaseOptions(baseUrl: 'https://www.zerochan.net'))
        ..httpClientAdapter = _FixtureAdapter((request) {
          expect(request.uri.path, '/101');
          expect(request.uri.query, 'json');
          return _json({
            'id': 101,
            'full': 'https://static.zerochan.net/Cat.full.101.png',
            'tags': ['cat'],
          });
        });
      addTearDown(() => dio.close(force: true));
      return (
        extractor: ZerochanDownloadFileUrlExtractor(
          client: ZerochanClient(dio: dio),
        ),
        post: TestPost(id: 101, tags: const {'cat'}),
        requestedQuality: 'sample',
        expectedUrl: 'https://static.zerochan.net/Cat.full.101.png',
        expectedQuality: 'original',
        expectedCookie: null,
      );
    },
  ),
  for (final resolution in ['480p', '720p', 'original', 'unknown'])
    (
      name: 'e621 Sample resolves $resolution',
      create: () => (
        extractor: const E621DownloadFileUrlExtractor(),
        post: _e621Video(resolution),
        requestedQuality: 'sample',
        expectedUrl: 'https://media.test/$resolution.webm',
        expectedQuality: resolution == 'unknown' ? 'custom' : resolution,
        expectedCookie: null,
      ),
    ),
  (
    name: 'AnimePictures requested Preview resolves Original and preserves cookie',
    create: () {
      final dio = Dio()
        ..httpClientAdapter = _FixtureAdapter((request) {
          if (request.uri.path == '/api/v3/posts/101') {
            return _json({
              'post': {'id': 101},
              'file_url': 'original.png',
            });
          }
          expect(request.uri.path, '/pictures/download_image/original.png');
          return ResponseBody.fromString(
            '',
            302,
            headers: const {
              'location': ['https://media.test/anime-original.png'],
              'set-cookie': ['download=allowed; Path=/'],
            },
          );
        });
      addTearDown(() => dio.close(force: true));
      return (
        extractor: AnimePicturesDownloadFileUrlExtractor(
          client: AnimePicturesClient(
            dio: dio,
            baseUrl: 'https://api.anime-pictures.net',
            cookie: 'session=test-fixture',
          ),
        ),
        post: TestPost(id: 101, tags: const {'cat'}),
        requestedQuality: 'preview',
        expectedUrl: 'https://media.test/anime-original.png',
        expectedQuality: 'original',
        expectedCookie: 'sitelang=en; session=test-fixture; download=allowed',
      );
    },
  ),
];

Post _e621Video(String resolution) =>
    dummyPost(
      id: 101,
      tags: const {'cat'},
      format: '.webm',
      originalImageUrl: 'https://media.test/original.webm',
      videoUrl: 'https://media.test/$resolution.webm',
    ).copyWith(
      booruData: E621PostData(
        generalTags: const {'cat'},
        metaTags: const {},
        speciesTags: const {},
        invalidTags: const {},
        loreTags: const {},
        upScore: 0,
        downScore: 0,
        favCount: 0,
        isFavorited: false,
        sources: const [],
        description: '',
        videoVariants: [
          const E621VideoVariantData(
            type: E621VideoVariantType.original,
            url: 'https://media.test/original.webm',
            size: 100,
            width: 1920,
            height: 1080,
            codec: 'vp9',
            fps: 30,
          ),
          if (resolution == '480p' || resolution == '720p')
            E621VideoVariantData(
              type: resolution == '480p'
                  ? E621VideoVariantType.v480p
                  : E621VideoVariantType.v720p,
              url: 'https://media.test/$resolution.webm',
              size: 50,
              width: 640,
              height: 480,
              codec: 'vp9',
              fps: 30,
            ),
        ],
      ),
    );

ResponseBody _json(Map<String, Object> data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: const {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.response);

  final ResponseBody Function(RequestOptions) response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => Future.value(response(options));

  @override
  void close({bool force = false}) {}
}
