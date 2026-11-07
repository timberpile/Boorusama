import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktoast/oktoast.dart';

import '../../../bulk_downloads/common.dart';
import '../../posts/details/progressive_image_test_utils.dart' as images;

final current = StateProvider<ContentAccessContext?>((ref) => null);

class _Extractor extends Mock implements DownloadFileUrlExtractor {}

class _Fs extends Mock implements AppFileSystem {}

class _Cache implements ImageCacheManager {
  final reads = <String>[];
  final values = <String, Uint8List>{};
  @override
  String generateCacheKey(String url, {String? customKey}) => customKey ?? url;
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) {
    reads.add(key);
    return values[key];
  }

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) {
    reads.add(key);
    return null;
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) {
    reads.add(key);
    return false;
  }

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {}
  @override
  Future<void> clearCache(String key) async {}
  @override
  Future<void> clearAllCache() async {}
  @override
  void invalidateCacheDirectory() {}
  @override
  Future<void> dispose() async {}
}

void main() {
  const site = 'https://safebooru.donmai.us';
  const viewer = BooruConfigViewer(
    imageDetaisQuality: null,
    videoQuality: null,
    viewerNotesFetchBehavior: null,
    settings: null,
  );
  final source = const AnonymousSourcePolicy().resolve(
    BooruType.danbooru,
    Uri.parse(site),
  )!;
  for (final unsafe in [true, false]) {
    testWidgets(
      'public share ${unsafe ? 'rejects unsafe URL' : 'revokes pending media'} without publishing',
      (tester) async {
        final cache = _Cache();
        final adapter = images.ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final fs = _Fs();
        when(fs.getTemporaryPath).thenAnswer((_) async => '/tmp');
        final key = ContentAccessKey(
          engine: BooruType.danbooru,
          siteNamespace: source.site.host,
          authEpoch: 1,
          policyEpoch: 1,
        );
        var active = true;
        final scope = AnonymousReadScope(
          source: source,
          key: key,
          createDio: () => dio,
          current: () => active,
        );
        final config = BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': '11111111-1111-4111-8111-111111111111',
          'booruId': BooruType.danbooru.id,
          'booruIdHint': BooruType.danbooru.id,
          'url': site,
        }).copyWith(anonymousReadScope: scope);
        final access = ContentAccessContext.anonymous(
          config: config,
          scope: scope,
        );
        final url = unsafe
            ? 'https://foreign.example.test/image.png'
            : '$site/image.png';
        final post = dummyPost(
          id: 42,
          sampleImageUrl: url,
          originalImageUrl: url,
          format: 'png',
        );
        var published = 0;
        var bypassCalls = 0;
        var dioReads = 0;
        cache.values[url] = images.targetPng;
        final container = ProviderContainer(
          overrides: [
            loggerProvider.overrideWithValue(AppLogger()),
            contentAccessContextProvider.overrideWith(
              (ref, key) => ref.watch(current),
            ),
            appFileSystemProvider.overrideWithValue(fs),
            downloadFileUrlExtractorProvider.overrideWith(
              (ref, auth) => _Extractor(),
            ),
            mediaUrlResolverProvider.overrideWith(
              (ref, auth) => const SampleMediaUrlResolver(),
            ),
            postLinkGeneratorProvider.overrideWith(
              (ref, auth) => const IntIdPostLinkGenerator(
                baseUrl: site,
                pathTemplate: 'posts/{id}',
              ),
            ),
            dioForWidgetProvider.overrideWith((ref, auth) {
              dioReads++;
              return dio;
            }),
            httpHeadersProvider.overrideWith(
              (ref, auth) => const {'User-Agent': 'fixture'},
            ),
            bypassDdosHeadersProvider.overrideWith((ref, url) {
              bypassCalls++;
              throw StateError('Unexpected bypass probe');
            }),
          ],
        );
        container.read(current.notifier).state = access;
        addTearDown(container.dispose);
        addTearDown(scope.dispose);
        addTearDown(() => dio.close(force: true));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: OKToast(child: TranslationProvider(child: child!)),
              ),
              home: Scaffold(
                body: UnifiedPostShareSheet(
                  post: post,
                  auth: config.auth,
                  viewer: viewer,
                  accessKey: key,
                  requireAccess: true,
                  imageCacheManager: cache,
                  imageClipboardWriter: (_) async {
                    published++;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (unsafe) {
          expect(cache.reads, isEmpty);
        } else {
          expect(cache.reads, isNotEmpty);
          expect(cache.reads.every((value) => value != url), isTrue);
        }
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Copy Image'));
          await tester.pump();
          if (!unsafe) {
            await images.pumpUntil(
              tester,
              () => adapter.pending.containsKey(url),
              reason: 'public image request',
            );
            active = false;
            container.read(current.notifier).state = null;
            await tester.pump();
            adapter.complete(url, images.targetPng);
          }
        });
        await tester.pumpAndSettle();
        expect(published, 0);
        expect(bypassCalls, 0);
        if (unsafe) {
          expect(dioReads, 0);
          expect(adapter.requests, isEmpty);
          expect(cache.reads, isEmpty);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
