import 'dart:io';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:image/image.dart' as img;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../../bulk_downloads/common.dart';
import 'share_test_utils.dart';

class _FileSystem extends Mock implements AppFileSystem {}

class _Cache extends Mock implements ManagedImageCacheManager {}

class _Lease extends ImageCacheFileLease {
  _Lease(this.path);
  @override
  final String path;
  var released = false;
  @override
  bool get isRetained => true;
  @override
  Future<void> release() async {
    released = true;
  }
}

const _auth = BooruConfigAuth(
  booruId: 1,
  booruIdHint: 1,
  url: 'https://site.test',
  apiKey: 'must-not-leak',
  login: 'private',
  passHash: null,
  proxySettings: null,
  networkSettings: null,
);
const _viewer = BooruConfigViewer(
  imageDetaisQuality: null,
  videoQuality: null,
  viewerNotesFetchBehavior: null,
  settings: null,
);

Post _post({String preview = 'https://site.test/sample.png'}) =>
    dummyPost(
      id: 42,
      sampleImageUrl: preview,
      format: 'png',
    ).copyWith(
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 1,
        source: 'https://site.test',
        profileIdHint: '00000000-0000-4000-8000-000000000001',
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Post post,
  required _Cache cache,
  required _FileSystem fs,
  ShareActionAdapter? adapter,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appFileSystemProvider.overrideWithValue(fs),
        defaultImageCacheManagerProvider.overrideWithValue(cache),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        mediaUrlResolverProvider.overrideWith(
          (ref, config) => const SampleMediaUrlResolver(),
        ),
        postLinkGeneratorProvider.overrideWith(
          (ref, config) => const IntIdPostLinkGenerator(
            baseUrl: 'https://site.test',
            pathTemplate: 'posts/{id}',
          ),
        ),
        downloadFileUrlExtractorProvider.overrideWith(
          (ref, config) => const UrlInsidePostExtractor(),
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
            post: post,
            auth: _auth,
            viewer: _viewer,
            imageCacheManager: cache,
            shareAdapter: adapter,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Links'));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

void main() {
  testWidgets('Copy emits only the URI and never prepares/downloads an image', (
    tester,
  ) async {
    final cache = _Cache();
    when(() => cache.generateCacheKey(any())).thenReturn('key');
    when(() => cache.getCachedFileBytes(any())).thenReturn(null);
    final fs = _FileSystem();
    final copied = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pump(tester, post: _post(), cache: cache, fs: fs);
    await tester.tap(find.byTooltip('Copy Boorusama link'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(copied, [
      BoorusamaPostLink.fromPost(_post(), auth: _auth)!.uri.toString(),
    ]);
    expect(copied.single, isNot(contains('private')));
    expect(copied.single, isNot(contains('must-not-leak')));
    verifyNever(fs.getTemporaryPath);
    verifyNever(() => cache.acquireFile(any()));
    dismissAllToast(showAnim: false);
    // Drain OKToast's fake-clock dismissal callbacks before disposing its host.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  for (final native in [false, true]) {
    testWidgets(
      'Share passes one image and the copied URI through ${native ? 'Android' : 'share_plus'}',
      (tester) async {
        final root = await tester.runAsync(
          () => Directory.systemTemp.createTemp('post-link-share-'),
        );
        addTearDown(() => root!.delete(recursive: true));
        final png = Uint8List.fromList(
          img.encodePng(img.Image(width: 1, height: 1)),
        );
        final file = File('${root!.path}/cacheimage/image.png');
        await tester.runAsync(() async {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png);
        });
        final lease = _Lease(file.path);
        final cache = _Cache();
        when(() => cache.generateCacheKey(any())).thenReturn('key');
        when(() => cache.getCachedFileBytes(any())).thenReturn(png);
        when(() => cache.acquireFile(any())).thenAnswer((_) async => lease);
        final fs = _FileSystem();
        when(fs.getTemporaryPath).thenAnswer((_) async => root.path);
        final expected =
            'Open in Boorusama\n${BoorusamaPostLink.fromPost(_post(), auth: _auth)!.uri}';
        var calls = 0;
        Future<void> check(String path, String mime, String? text) async {
          calls++;
          expect(mime, 'image/png');
          expect(text, expected);
          expect(
            lease.released,
            isFalse,
            reason: 'The receiving platform still owns the handoff',
          );
          expect(await File(path).readAsBytes(), png);
        }

        final messenger = tester.binding.defaultBinaryMessenger;
        const channel = MethodChannel('boorusama/image_clipboard');
        if (native) {
          messenger.setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'shareImageFile');
            final args = call.arguments as Map;
            await check(
              args['path'] as String,
              args['mimeType'] as String,
              args['text'] as String?,
            );
            return null;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        await _pump(
          tester,
          post: _post(),
          cache: cache,
          fs: fs,
          adapter: native
              ? null
              : ShareActionAdapter((params) async {
                  expect(params.uri, isNull);
                  expect(params.files, hasLength(1));
                  expect(params.sharePositionOrigin!.width, greaterThan(0));
                  expect(params.sharePositionOrigin!.height, greaterThan(0));
                  await check(
                    params.files!.single.path,
                    params.files!.single.mimeType!,
                    params.text,
                  );
                  return const ShareResult('', ShareResultStatus.success);
                }),
        );
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Share image and Boorusama link'));
          await pumpUntilShareCondition(
            tester,
            () =>
                calls == 1 && shareActionEnabled(tester, 'Copy Boorusama link'),
            reason:
                'The complete file-and-caption handoff should release its lease',
          );
        });
        expect(calls, 1);
        expect(lease.released, isTrue);
        verify(() => cache.acquireFile('key')).called(1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('missing preview explains failed Share while Copy remains usable', (
    tester,
  ) async {
    final cache = _Cache();
    when(() => cache.generateCacheKey(any())).thenReturn('key');
    when(() => cache.getCachedFileBytes(any())).thenReturn(null);
    final fs = _FileSystem();
    await _pump(
      tester,
      post: _post(preview: ''),
      cache: cache,
      fs: fs,
    );
    await tester.tap(find.byTooltip('Share image and Boorusama link'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(
      find.text(
        'No image is available to share with this link. You can still copy the link.',
      ),
      findsOneWidget,
    );
    expect(shareActionEnabled(tester, 'Copy Boorusama link'), isTrue);
    verifyNever(fs.getTemporaryPath);
    verifyNever(() => cache.acquireFile(any()));
    await tester.pumpWidget(const SizedBox());
  });
}
