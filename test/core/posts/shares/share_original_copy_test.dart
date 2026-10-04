import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:image/image.dart' as img;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktoast/oktoast.dart';

import '../../../bulk_downloads/common.dart';

class _FileSystem extends Mock implements AppFileSystem {}

class _CacheManager extends Mock implements ImageCacheManager {}

class _ExactExtractor implements DownloadFileUrlExtractor {
  var calls = 0;

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    expect(quality, 'original');
    calls++;
    return const DownloadUrlData.urlOnly('https://cdn.test/exact.png');
  }
}

void main() {
  testWidgets('copying Original prepares the exact image and reports success', (
    tester,
  ) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('share-original-copy-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    final fs = _FileSystem();
    when(fs.getTemporaryPath).thenAnswer((_) async => root!.path);
    when(() => fs.readBytes(any())).thenAnswer(
      (invocation) =>
          File(invocation.positionalArguments.single as String).readAsBytes(),
    );
    final cache = _CacheManager();
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    final cachedImage = File("${root!.path}/cacheimage/exact.png");
    await tester.runAsync(() async {
      await cachedImage.parent.create(recursive: true);
      await cachedImage.writeAsBytes(png);
    });
    when(() => cache.getCachedFilePath(any())).thenReturn(cachedImage.path);
    when(() => cache.generateCacheKey(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.single as String,
    );
    when(
      () => cache.getCachedFileBytes('https://cdn.test/exact.png'),
    ).thenReturn(png);
    final extractor = _ExactExtractor();
    String? clipboardPath;
    const auth = BooruConfigAuth(
      booruId: 1,
      booruIdHint: 1,
      url: 'https://site.test',
      apiKey: null,
      login: null,
      passHash: null,
      proxySettings: null,
      networkSettings: null,
    );
    const viewer = BooruConfigViewer(
      imageDetaisQuality: null,
      videoQuality: null,
      viewerNotesFetchBehavior: null,
      settings: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFileSystemProvider.overrideWithValue(fs),
          downloadFileUrlExtractorProvider.overrideWith(
            (ref, config) => extractor,
          ),
          mediaUrlResolverProvider.overrideWith(
            (ref, config) => const SampleMediaUrlResolver(),
          ),
          postLinkGeneratorProvider.overrideWith(
            (ref, config) => const IntIdPostLinkGenerator(
              baseUrl: 'https://site.test',
              pathTemplate: 'posts/{id}',
            ),
          ),
          bypassDdosHeadersProvider.overrideWith((ref, url) => const {}),
          httpHeadersProvider.overrideWith((ref, config) => const {}),
          dioForWidgetProvider.overrideWith((ref, config) => Dio()),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: OKToast(child: TranslationProvider(child: child!)),
          ),
          home: Scaffold(
            body: UnifiedPostShareSheet(
              post: dummyPost(
                id: 42,
                sampleImageUrl: 'https://site.test/sample.png',
                originalImageUrl: 'https://site.test/preview.png',
                format: 'png',
              ),
              auth: auth,
              viewer: viewer,
              imageCacheManager: cache,
              imageFileClipboardWriter: (path, mimeType) async {
                expect(mimeType, 'image/png');
                expect(File(path).readAsBytesSync(), png);
                clipboardPath = path;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Copy original'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Copy original'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsOneWidget);
    expect(find.text('exact.png'), findsNothing);
    final staging = Directory('${root.path}/boorusama-share');
    expect(staging.existsSync(), isFalse);
    expect(clipboardPath, isNotNull);
    expect(File(clipboardPath!).existsSync(), isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'slow final image read and clipboard write keep progress until Copy finishes',
    (
      tester,
    ) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('share-original-pending-read-'),
      );
      addTearDown(() => root!.delete(recursive: true));
      final readStarted = Completer<void>();
      final pendingRead = Completer<Uint8List>();
      final writeStarted = Completer<void>();
      final pendingWrite = Completer<void>();
      final fs = _FileSystem();
      when(fs.getTemporaryPath).thenAnswer((_) async => root!.path);
      when(() => fs.readBytes(any())).thenAnswer((_) {
        if (!readStarted.isCompleted) readStarted.complete();
        return pendingRead.future;
      });
      final cache = _CacheManager();
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      final cachedImage = File("${root!.path}/cacheimage/exact.png");
      await tester.runAsync(() async {
        await cachedImage.parent.create(recursive: true);
        await cachedImage.writeAsBytes(png);
      });
      when(() => cache.getCachedFilePath(any())).thenReturn(cachedImage.path);
      when(() => cache.generateCacheKey(any())).thenAnswer(
        (invocation) => invocation.positionalArguments.single as String,
      );
      when(
        () => cache.getCachedFileBytes('https://cdn.test/exact.png'),
      ).thenReturn(png);
      const auth = BooruConfigAuth(
        booruId: 1,
        booruIdHint: 1,
        url: 'https://site.test',
        apiKey: null,
        login: null,
        passHash: null,
        proxySettings: null,
        networkSettings: null,
      );
      const viewer = BooruConfigViewer(
        imageDetaisQuality: null,
        videoQuality: null,
        viewerNotesFetchBehavior: null,
        settings: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appFileSystemProvider.overrideWithValue(fs),
            downloadFileUrlExtractorProvider.overrideWith(
              (ref, config) => _ExactExtractor(),
            ),
            mediaUrlResolverProvider.overrideWith(
              (ref, config) => const SampleMediaUrlResolver(),
            ),
            postLinkGeneratorProvider.overrideWith(
              (ref, config) => const IntIdPostLinkGenerator(
                baseUrl: 'https://site.test',
                pathTemplate: 'posts/{id}',
              ),
            ),
            bypassDdosHeadersProvider.overrideWith((ref, url) => const {}),
            httpHeadersProvider.overrideWith((ref, config) => const {}),
            dioForWidgetProvider.overrideWith((ref, config) => Dio()),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: OKToast(child: TranslationProvider(child: child!)),
            ),
            home: Scaffold(
              body: UnifiedPostShareSheet(
                post: dummyPost(
                  id: 42,
                  sampleImageUrl: 'https://site.test/sample.png',
                  originalImageUrl: 'https://site.test/preview.png',
                  format: 'png',
                ),
                auth: auth,
                viewer: viewer,
                imageCacheManager: cache,
                imageClipboardWriter: (bytes) {
                  expect(bytes, png);
                  writeStarted.complete();
                  return pendingWrite.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Copy original'));
        await Future<void>.delayed(const Duration(milliseconds: 650));
      });
      await tester.pump();
      expect(readStarted.isCompleted, isTrue);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );

      pendingRead.complete(png);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      expect(writeStarted.isCompleted, isTrue);
      expect(find.text('Copying to clipboard…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );

      pendingWrite.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
}
