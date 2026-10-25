import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/filename/providers.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/reboot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../application/support/fake_booru_backend.dart';
import '../support/boorusama_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual mixed fallback isolates equal IDs and respects denied bulk',
    () async {
      final backend = FakeBooruBackend();
      final downloads = MemoryDownloadService();
      final runtime = backend.createRuntime(
        configs: [backend.config, backend.configB],
        settings: Settings.defaultSettings.copyWith(
          downloadQuality: DownloadQuality.sample,
          downloadPath: '/global',
          downloadSidecarFormat: SidecarFormat.json,
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
          downloadFilenameBuilderProvider.overrideWith((_, _) => null),
          downloadFileUrlExtractorProvider.overrideWith(
            (_, _) => const UrlInsidePostExtractor(),
          ),
          downloadMultipleFileCheckProvider.overrideWith(
            (_, auth) =>
                () => auth.url != backend.configB.url,
          ),
          httpHeadersProvider.overrideWith(
            (_, auth) => {'Authorization': 'fixture-${auth.url}'},
          ),
          bypassDdosHeadersProvider.overrideWith(
            (_, _) => Future.value(<String, String>{}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkProvider.future);
      Bookmark stored(BooruConfig config, int id, {String? orphanHost}) {
        final source = orphanHost ?? config.url;
        final post = TestPost(
          id: id,
          origin: PostOrigin.fromSource(
            booruType: config.auth.booruType,
            booruId: config.booruId,
            source: source,
            profileIdHint: orphanHost == null ? config.id : null,
          ),
          sampleImageUrl: '$source/sample.jpg',
          originalImageUrl: '$source/original.png',
          booruData: const LegacyPostData(
            typeKey: 'legacy_fixture',
            custom: {},
          ),
        );
        return Bookmark.fromSnapshot(
          id: id,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          snapshot: const StoredPostCodec().encode(post),
          post: post,
          postId: id,
          sourceUrl: '$source/posts/$id',
        );
      }

      await container.read(bookmarkProvider.notifier).downloadBookmarks(
        backend.configB.auth,
        backend.configB.download,
        [
          stored(backend.config, 42),
          stored(backend.config, 42, orphanHost: 'https://orphan.test'),
          stored(backend.configB, 42),
          stored(backend.configB, 43),
        ],
      );
      expect(downloads.requests, hasLength(2));
      final owner = downloads.requests[0];
      final orphan = downloads.requests[1];
      expect(owner.url, '${backend.config.url}/sample.jpg');
      expect(orphan.url, 'https://orphan.test/sample.jpg');
      expect(owner.filename, isNot(orphan.filename));
      expect(owner.headers?['Authorization'], 'fixture-${backend.config.url}');
      expect(orphan.headers?['Authorization'], isNull);
      expect(owner.sidecar!.postUrl, '${backend.config.url}/posts/42');
      expect(orphan.sidecar!.postUrl, 'https://orphan.test/posts/42');
      expect(
        downloads.requests.every((r) => r.sidecar!.quality == 'sample'),
        isTrue,
      );
    },
  );
  for (final orphan in [false, true]) {
    for (final quality in DownloadQuality.values) {
      for (final bulk in [false, true]) {
        test(
          'actual snapshot fallback shares $quality policy (orphan=$orphan, bulk=$bulk)',
          () async {
            final backend = FakeBooruBackend();
            final owner = BooruConfig.fromJson({
              ...backend.config.toJson(),
              'id': backend.config.id,
              'customDownloadFileNameFormat': 'owned_{id}.{extension}',
              'customBulkDownloadFileNameFormat': 'owned_{id}.{extension}',
              'customDownloadLocation': '/owner',
            });
            final downloads = MemoryDownloadService();
            final source = orphan ? 'https://orphan.test' : owner.url;
            Post postFor(int id) =>
                TestPost(
                  id: id,
                  origin: PostOrigin.fromSource(
                    booruType: owner.auth.booruType,
                    booruId: owner.booruId,
                    source: source,
                    profileIdHint: orphan ? null : owner.id,
                  ),
                  thumbnailImageUrl: '$source/thumb.jpg',
                  sampleImageUrl: '$source/sample.jpg',
                  originalImageUrl: '$source/original.png',
                  format: 'png',
                  fileSize: 1234,
                ).copyWith(
                  booruData: const LegacyPostData(
                    typeKey: 'legacy_fixture',
                    custom: {},
                  ),
                );
            final post = postFor(42);
            final bookmark = Bookmark.fromSnapshot(
              id: 1,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              snapshot: const StoredPostCodec().encode(post),
              post: post,
              postId: post.id,
              sourceUrl: '$source/posts/42',
            );
            final runtime = backend.createRuntime(
              configs: [owner, backend.configB],
              settings: Settings.defaultSettings.copyWith(
                downloadQuality: quality,
                downloadPath: '/global',
                downloadSidecarFormat: SidecarFormat.json,
                downloadFileExistedBehavior: DownloadFileExistedBehavior.skip,
                downloadNetworkPolicy: DownloadNetworkPolicy.wifiOnly,
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
                downloadFilenameBuilderProvider.overrideWith((_, _) => null),
                downloadFileUrlExtractorProvider.overrideWith(
                  (_, _) => const UrlInsidePostExtractor(),
                ),
                httpHeadersProvider.overrideWith(
                  (_, auth) => {'Authorization': 'fixture-${auth.url}'},
                ),
                bypassDdosHeadersProvider.overrideWith(
                  (_, _) => Future.value(<String, String>{}),
                ),
              ],
            );
            addTearDown(container.dispose);
            await container.read(bookmarkProvider.future);
            final notifier = container.read(bookmarkProvider.notifier);
            final selection = [
              bookmark,
              if (bulk)
                Bookmark.fromSnapshot(
                  id: 2,
                  createdAt: bookmark.createdAt,
                  updatedAt: bookmark.updatedAt,
                  snapshot: const StoredPostCodec().encode(
                    postFor(43),
                  ),
                  post: postFor(43),
                  postId: 43,
                  sourceUrl: '$source/posts/43',
                ),
            ];
            await notifier.downloadBookmarks(
              backend.configB.auth,
              backend.configB.download,
              selection,
            );
            expect(downloads.requests, hasLength(bulk ? 2 : 1));
            final request = downloads.requests.first;
            expect(
              request.networkConstraint,
              DownloadNetworkConstraint.wifiRequired,
            );
            expect(request.sidecar!.postUrl, '$source/posts/42');
            expect(
              request.metadata!.fileSize,
              quality == DownloadQuality.original ? 1234 : isNull,
            );
            final expectedUrl = switch (quality) {
              DownloadQuality.original => '$source/original.png',
              DownloadQuality.sample => '$source/sample.jpg',
              DownloadQuality.preview => '$source/thumb.jpg',
            };
            expect(request.url, expectedUrl);
            expect(request.sidecar!.quality, quality.name);
            expect(request.path, orphan ? '/global' : '/owner');
            expect(request.skipIfExists, isTrue);
            expect(
              request.headers?['Authorization'],
              orphan ? isNull : 'fixture-${owner.url}',
            );
            final stem = orphan ? 'orphan.test_42' : 'owned_42';
            expect(
              request.filename,
              quality == DownloadQuality.original
                  ? '$stem.png'
                  : '${stem}_${quality.name}.jpg',
            );
            await notifier.downloadBookmarks(
              backend.configB.auth,
              backend.configB.download,
              selection,
            );
            expect(
              downloads.requests[bulk ? 2 : 1].filename,
              request.filename,
              reason: 'the same rendition must use a deterministic duplicate target',
            );
          },
        );
      }
    }
  }
}
