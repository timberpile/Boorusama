import 'package:boorusama/boorus/pixiv/posts/link_generator.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/links/boorusama_group_link.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/share_group_target.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:kurumi/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../../boorus/pixiv/works/work_test_fixtures.dart';
import '../../../bulk_downloads/common.dart';
import '../../../support/fakes/memory_app_file_system.dart';

class _Cache extends Mock implements ManagedImageCacheManager {}

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
  required AppFileSystem fs,
  BooruConfigAuth auth = _auth,
  ShareActionAdapter? adapter,
  String profileName = 'My Danbooru',
  ShareGroupTarget? group,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (group != null) ...[
          contentAccessContextProvider.overrideWith(
            (ref, key) => key == group.access.key ? group.access : null,
          ),
          contentPostVisibilityProvider.overrideWith(
            (ref, request) => AsyncData(request.access == group.access.key),
          ),
        ],
        loggerProvider.overrideWithValue(AppLogger()),
        appFileSystemProvider.overrideWithValue(fs),
        defaultImageCacheManagerProvider.overrideWithValue(cache),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        mediaUrlResolverProvider.overrideWith(
          (ref, config) => const SampleMediaUrlResolver(),
        ),
        postLinkGeneratorProvider.overrideWith(
          (ref, config) => config.booruType == BooruType.pixiv
              ? const PixivPostLinkGenerator()
              : const IntIdPostLinkGenerator(
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
        theme: ThemeData(
          brightness: tester.platformDispatcher.platformBrightness,
          extensions: const [KurumiExtendedColorScheme()],
        ),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: OKToast(child: TranslationProvider(child: child!)),
        ),
        home: Scaffold(
          body: UnifiedPostShareSheet(
            post: post,
            group: group,
            accessKey: group?.access.key,
            auth: group?.access.config?.auth ?? auth,
            profileName: profileName,
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
  testWidgets('post Links exposes one file action, no raw or mixed share', (
    tester,
  ) async {
    final cache = _Cache();
    when(() => cache.generateCacheKey(any())).thenReturn('key');
    when(() => cache.getCachedFileBytes(any())).thenReturn(null);
    await _pump(tester, post: _post(), cache: cache, fs: MemoryAppFileSystem());
    expect(find.byKey(const ValueKey('share-bslink-file')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('share-bslink-file')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('share-bslink-image')), findsNothing);
    expect(find.byTooltip('Copy Boorusama Link'), findsNothing);
    expect(find.byTooltip('Share Image and Boorusama Link'), findsNothing);
    expect(find.textContaining('boorusama://'), findsNothing);
    expect(find.byTooltip('Copy Post Link'), findsOneWidget);
    expect(find.byTooltip('Share Booru Link'), findsOneWidget);
    expect(find.byTooltip('Copy Image Link'), findsOneWidget);
    expect(find.byTooltip('Copy Post ID'), findsOneWidget);
    final postId = find.byKey(const ValueKey(SharePayloadId.postId));
    final label = find.descendant(of: postId, matching: find.text('Post ID'));
    final value = find.descendant(of: postId, matching: find.text('42'));
    expect(
      tester.getTopLeft(value).dy,
      greaterThan(tester.getTopLeft(label).dy),
    );
    expect(find.text('https://site.test/posts/42'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final page in [0, 1]) {
    testWidgets('Pixiv page $page copies and shares the original artwork ID', (
      tester,
    ) async {
      final access = workAccess();
      final post = pixivWorkPagePosts(
        work(id: 123456, pageCount: 2),
        access,
      )[page];
      final copied = <String>[];
      final shared = <ShareParams>[];
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
      final cache = _Cache();
      when(() => cache.generateCacheKey(any())).thenReturn('key');
      when(() => cache.getCachedFileBytes(any())).thenReturn(null);
      await _pump(
        tester,
        post: post,
        auth: access.config!.auth,
        profileName: 'Pixiv Reading',
        cache: cache,
        fs: MemoryAppFileSystem(),
        adapter: ShareActionAdapter((params) async {
          shared.add(params);
          return const ShareResult('', ShareResultStatus.success);
        }),
      );

      expect(find.text('123456'), findsOneWidget);
      expect(find.text(post.id.toString()), findsNothing);
      await tester.tap(find.byTooltip('Copy Post ID'));
      await tester.pump();
      await tester.tap(find.byTooltip('Share Post ID'));
      await tester.pump();
      expect(copied, ['123456']);
      expect(shared.single.text, '123456');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  for (final poolId in [42, 43]) {
    testWidgets('one row shares Post and exact Pool files for pool $poolId', (
      tester,
    ) async {
      final cache = _Cache();
      when(() => cache.generateCacheKey(any())).thenReturn('key');
      when(() => cache.getCachedFileBytes(any())).thenReturn(null);
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
        'booruId': BooruType.danbooru.id,
        'booruIdHint': BooruType.danbooru.id,
        'url': 'https://site.test',
        'name': 'Pool Source',
      });
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse(profile.url),
        kind: ContentKind.group,
        sourceKey: 'pool:$poolId',
      );
      final group = ShareGroupTarget(
        link: BoorusamaGroupLink.fromReference(reference),
        groupName: 'Summer Collection',
        access: ContentAccessContext.profile(
          config: profile,
          authEpoch: 1,
          policyEpoch: 1,
        ),
      );
      final fs = MemoryAppFileSystem();
      final sent = <Uri>[];
      final fileNames = <String>[];
      final captions = <String?>[];
      await _pump(
        tester,
        post: _post(),
        cache: cache,
        fs: fs,
        group: group,
        adapter: ShareActionAdapter((params) async {
          if (params.files case final files?) {
            fileNames.add(files.single.name);
            captions.add(params.text);
            sent.add(
              BoorusamaLinkFile.decode(await fs.readBytes(files.single.path))
                  .uri,
            );
          } else {
            sent.add(params.uri!);
          }
          return const ShareResult('', ShareResultStatus.success);
        }),
      );
      final row = find.byKey(const ValueKey('share-bslink-file'));
      for (final label in [
        'Share current post link file',
        'Share entire collection link file',
      ]) {
        final button = find.descendant(
          of: row,
          matching: find.byTooltip(label),
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      expect(find.text('Post Link'), findsOneWidget);
      expect(find.text('Pool Link'), findsOneWidget);
      ConfigAwareWebsiteLogo icon(SharePayloadId id) => tester.widget(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(ConfigAwareWebsiteLogo),
        ),
      );
      expect(
        icon(SharePayloadId.poolLink).url,
        icon(SharePayloadId.booruLink).url,
      );
      expect(fileNames, [
        'my-danbooru-post-42.bslink',
        'pool-source-pool-$poolId.bslink',
      ]);
      expect(captions, [
        'Post 42 on My Danbooru',
        'Summer Collection on Pool Source',
      ]);
      for (final label in ['Share Booru Link', 'Share Pool Link']) {
        await tester.tap(find.byTooltip(label));
        await tester.pumpAndSettle();
      }
      expect(sent, [
        BoorusamaPostLink.fromPost(_post(), auth: profile.auth)!.uri,
        group.link.uri,
        Uri.parse('https://site.test/posts/42'),
        Uri.parse('https://site.test/pools/$poolId'),
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (pageAuthor, workAuthor, workId, expectedPage, expectedWork) in [
    (
      null,
      'Saved Artist',
      42,
      'Post 42 by Saved Artist on Pixiv Reading',
      'Blue Hour by Saved Artist on Pixiv',
    ),
    (
      'Page Artist',
      null,
      42,
      'Post 42 by Page Artist on Pixiv Reading',
      'Blue Hour by Page Artist on Pixiv',
    ),
    (null, null, 42, 'Post 42 on Pixiv Reading', 'Blue Hour on Pixiv'),
    (
      'Page Artist',
      null,
      43,
      'Post 42 by Page Artist on Pixiv Reading',
      'Blue Hour on Pixiv',
    ),
  ]) {
    testWidgets(
      'Pixiv captions for Page author $pageAuthor and Work $workId author $workAuthor',
      (
        tester,
      ) async {
        final access = workAccess();
        final page = pixivWorkPagePosts(
          work(id: 42, pageCount: 1, artist: pageAuthor),
          access,
        ).single;
        final workReference = pixivWorkReference(access, workId);
        final group = ShareGroupTarget(
          link: BoorusamaGroupLink.fromReference(workReference),
          access: access,
          groupName: 'Blue Hour',
          author: workAuthor,
        );
        final cache = _Cache();
        when(() => cache.generateCacheKey(any())).thenReturn('key');
        when(() => cache.getCachedFileBytes(any())).thenReturn(null);
        final captions = <String?>[];
        await _pump(
          tester,
          post: page,
          group: group,
          cache: cache,
          profileName: 'Pixiv Reading',
          fs: MemoryAppFileSystem(),
          adapter: ShareActionAdapter((params) async {
            captions.add(params.text);
            return const ShareResult('', ShareResultStatus.success);
          }),
        );
        await tester.tap(find.byTooltip('Share current post link file'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Share entire collection link file'));
        await tester.pumpAndSettle();
        expect(captions, [expectedPage, expectedWork]);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('link-file actions fit narrow enlarged $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final cache = _Cache();
      when(() => cache.generateCacheKey(any())).thenReturn('key');
      when(() => cache.getCachedFileBytes(any())).thenReturn(null);
      await _pump(
        tester,
        post: _post(),
        cache: cache,
        fs: MemoryAppFileSystem(),
      );
      final tile = find.byKey(const ValueKey('share-bslink-file'));
      final icon = find.descendant(
        of: tile,
        matching: find.byType(Image),
      );
      expect(icon, findsOneWidget);
      expect(tester.widget<Image>(icon).image, isA<AssetImage>());
      expect(
        (tester.widget<Image>(icon).image as AssetImage).assetName,
        'assets/icon/icon-512x512.png',
      );
      expect(
        tester.getSize(
          find.ancestor(of: icon, matching: find.byType(ClipRect)).first,
        ),
        const Size(24, 24),
      );
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.share)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final preview in ['https://site.test/sample.png', '']) {
    testWidgets('standalone post document needs no image: $preview', (
      tester,
    ) async {
      final cache = _Cache();
      when(() => cache.generateCacheKey(any())).thenReturn('key');
      when(() => cache.getCachedFileBytes(any())).thenReturn(null);
      final fs = MemoryAppFileSystem();
      final post = _post(preview: preview);
      var calls = 0;
      await _pump(
        tester,
        post: post,
        cache: cache,
        fs: fs,
        adapter: ShareActionAdapter((params) async {
          calls++;
          expect(params.files, hasLength(1));
          expect(params.uri, isNull);
          expect(params.text, 'Post 42 on My Danbooru');
          final attachment = params.files!.single;
          expect(attachment.mimeType, BoorusamaLinkFile.mimeType);
          expect(attachment.name, 'my-danbooru-post-42.bslink');
          expect(params.sharePositionOrigin!.width, greaterThan(0));
          expect(
            BoorusamaLinkFile.decode(await fs.readBytes(attachment.path)).uri,
            BoorusamaPostLink.fromPost(post, auth: _auth)!.uri,
          );
          return const ShareResult('', ShareResultStatus.success);
        }),
      );
      await tester.tap(find.byTooltip('Share current post link file'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(calls, 1);
      verifyNever(() => cache.acquireFile(any()));
      verifyNever(() => cache.beginFileWrite(any()));
      expect(find.textContaining('No image is available'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
