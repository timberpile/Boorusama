import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_identity.dart';
import 'package:boorusama/boorus/danbooru/artists/urls/widgets.dart';
import 'package:boorusama/foundation/url_launcher.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/widgets/website_logo.dart';
import 'package:dio/dio.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../core/search/following_topics/following_topic_test_utils.dart';
import '../core/posts/details/progressive_image_test_utils.dart' as images;

const _socialUrls = [
  'https://x.com/menheragirl_inc',
  'https://twitter.com/example_name',
  'https://x.com/i/user/3147427',
  'https://www.youtube.com/@ktnazm0702',
  'https://www.youtube.com/channel/UC123_Abc',
  'https://youtube.com/c/SomeName',
  'https://youtube.com/user/SomeName',
  'https://www.tiktok.com/@ktnazm0702',
  'https://www.threads.net/@hakam',
  'https://www.threads.com/@hakam',
  'https://nico.ms/user/121151926',
  'https://www.nicovideo.jp/user/121151926',
  'https://lit.link/ktnazm0702',
  'https://www.pixiv.net/users/12345',
  'https://unknown.example/artist/abc?ref=source#about',
];

void main() {
  testWidgets(
    'Socials branding follows the host for profile and other site links',
    (tester) async {
      final launcher = _Launcher();
      final harness = FollowingTopicHarness(
        overrides: [externalUrlLauncherProvider.overrideWithValue(launcher)],
      );
      addTearDown(harness.dispose);
      for (final (url, icon) in [
        ('https://www.reddit.com/user/artist', FontAwesomeIcons.redditAlien),
        (
          'https://old.reddit.com/r/art/comments/123',
          FontAwesomeIcons.redditAlien,
        ),
        ('https://www.pixiv.net/stacc/artist', FontAwesomeIcons.pixiv),
        ('https://www.pixiv.net/en/artworks/123', FontAwesomeIcons.pixiv),
        ('https://www.pixiv.net/', FontAwesomeIcons.pixiv),
        ('https://www.patreon.com/c/artist', FontAwesomeIcons.patreon),
        (
          'https://m.facebook.com/profile.php?id=123',
          FontAwesomeIcons.facebookF,
        ),
        ('https://www.instagram.com/artist/', FontAwesomeIcons.instagram),
        ('https://bsky.app/profile/artist.example', FontAwesomeIcons.bluesky),
      ]) {
        await harness.pump(
          tester,
          Scaffold(
            body: DanbooruArtistUrlChips(artistUrls: [url], showLabels: true),
          ),
        );
        expect(tester.widget<FaIcon>(find.byType(FaIcon)).icon, icon.data);
        expect(find.byType(ConfigAwareWebsiteLogo), findsNothing);
        await tester.tap(find.byTooltip(url));
        await tester.pump();
        expect(launcher.urls.last, Uri.parse(url));
      }
    },
  );

  for (final success in [true, false]) {
    testWidgets(
      'unlisted social favicons use the cached loader and keep links usable ($success)',
      (tester) async {
        const url = 'https://reddit.com.other.example/artist/abc?ref=original';
        final adapter = images.ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final launcher = _Launcher();
        final cache = images.TestImageCache({});
        final harness = FollowingTopicHarness(
          loadImages: true,
          imageCacheManager: cache,
          overrides: [
            faviconDioProvider.overrideWithValue(dio),
            externalUrlLauncherProvider.overrideWithValue(launcher),
          ],
        );
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          const Scaffold(
            body: DanbooruArtistUrlChips(artistUrls: [url], showLabels: true),
          ),
        );
        final logo = tester.widget<WebsiteLogo>(find.byType(WebsiteLogo));
        expect(logo.size, 16);
        expect(logo.cacheManager, same(cache));
        expect(
          Uri.parse(logo.url!).queryParameters['domain'],
          'https://reddit.com.other.example/',
        );
        await tester.runAsync(() async {
          await images.pumpUntil(
            tester,
            () => adapter.pending.containsKey(logo.url),
            reason: 'favicon request',
          );
          adapter.complete(
            logo.url!,
            success ? images.targetPng : Uint8List(0),
            status: success ? 200 : 404,
          );
          if (success) {
            await images.waitForPixel(tester, [0, 0, 255, 255]);
          } else {
            await images.pumpUntil(
              tester,
              () => find
                  .byIcon(FontAwesomeIcons.globe.data)
                  .evaluate()
                  .isNotEmpty,
              reason: 'favicon fallback',
            );
          }
        });
        await tester.tap(find.byTooltip(url));
        await tester.pump();
        expect(launcher.urls, [Uri.parse(url)]);
        expect(adapter.requests, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.binding.imageCache.clear();
      },
    );
  }

  testWidgets(
    'each social chip launches the original URL, including generic sites',
    (tester) async {
      final launcher = _Launcher();
      final harness = FollowingTopicHarness(
        overrides: [externalUrlLauncherProvider.overrideWithValue(launcher)],
      );
      addTearDown(harness.dispose);
      for (final url in _socialUrls) {
        await harness.pump(
          tester,
          Scaffold(
            body: DanbooruArtistUrlChips(
              artistUrls: [url, 'javascript:alert(1)', 'https://'],
              showLabels: true,
            ),
          ),
        );
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(
          tester.getSize(find.byType(OutlinedButton)).height,
          greaterThanOrEqualTo(44),
        );
        final generic = {
          ArtistUrlPlatform.niconico,
          ArtistUrlPlatform.litLink,
          ArtistUrlPlatform.web,
        }.contains(artistUrlPresentation(url)!.platform);
        if (generic) {
          expect(
            tester
                .widget<ConfigAwareWebsiteLogo>(
                  find.byType(ConfigAwareWebsiteLogo),
                )
                .size,
            16,
          );
        } else {
          expect(tester.widget<FaIcon>(find.byType(FaIcon)).size, 16);
        }
        await tester.tap(find.byTooltip(url));
        await tester.pump();
        expect(launcher.urls.last, Uri.parse(url));
        if (url.contains('/i/user/')) {
          expect(find.text('user ID 3147427'), findsOneWidget);
          expect(find.textContaining('@3147427'), findsNothing);
        }
        if (url.contains('/channel/')) {
          expect(find.text('channel ID UC123_Abc'), findsOneWidget);
        }
        final presentation = artistUrlPresentation(url)!;
        if ({
          ArtistUrlPlatform.niconico,
          ArtistUrlPlatform.litLink,
          ArtistUrlPlatform.web,
        }.contains(presentation.platform)) {
          expect(
            find.textContaining(presentation.platformLabel),
            findsOneWidget,
          );
        } else {
          expect(find.textContaining(presentation.platformLabel), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
      expect(launcher.urls, _socialUrls.map(Uri.parse).toList());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'collapsed social chips stay in one reachable row at 320 dp and ${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final launcher = _Launcher();
        final harness = FollowingTopicHarness(
          overrides: [externalUrlLauncherProvider.overrideWithValue(launcher)],
        );
        addTearDown(harness.dispose);
        bool? overflow;
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 700),
              padding: const EdgeInsets.only(bottom: 24),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: DanbooruArtistUrlChips(
                artistUrls: _socialUrls,
                showLabels: true,
                singleRow: true,
                onOverflowChanged: (value) => overflow = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(overflow, isTrue);
        expect(find.byType(Wrap), findsNothing);
        expect(find.byType(OutlinedButton), findsNWidgets(_socialUrls.length));
        final tops = find
            .byType(OutlinedButton)
            .evaluate()
            .map(
              (element) => tester.getTopLeft(find.byWidget(element.widget)).dy,
            )
            .toSet();
        expect(tops, hasLength(1));
        final paint = tester.widget<CustomPaint>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.foregroundPainter is ScrollbarPainter,
          ),
        );
        final painter = paint.foregroundPainter! as ScrollbarPainter;
        final opacity = painter.fadeoutOpacityAnimation;
        expect(opacity.value, 0);
        final drag = await tester.startGesture(
          tester.getCenter(find.byType(SingleChildScrollView)),
        );
        await drag.moveBy(const Offset(-80, 0));
        await drag.moveBy(const Offset(-80, 0));
        await tester.pumpAndSettle();
        expect(opacity.value, greaterThan(0));
        await drag.up();
        // Advance the test clock past the scrollbar's idle fade delay.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(opacity.value, 0);
        final finalChip = find.byTooltip(_socialUrls.last);
        expect(finalChip.hitTestable(), findsNothing);
        await tester.dragUntilVisible(
          finalChip.hitTestable(),
          find.byType(SingleChildScrollView),
          const Offset(-240, 0),
          maxIteration: 30,
        );
        await tester.tap(finalChip);
        await tester.pump();
        expect(launcher.urls, [Uri.parse(_socialUrls.last)]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [
    (width: 320.0, scale: 1.0),
    (width: 320.0, scale: 2.0),
    (width: 350.0, scale: 2.0),
  ]) {
    testWidgets(
      'header actions remain at the safe trailing edge ${size.width}/${size.scale}',
      (tester) async {
        tester.view.physicalSize = Size(size.width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final banner = ArtistBannerSnapshot();
        addTearDown(banner.dispose);
        final harness = FollowingTopicHarness();
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          MediaQuery(
            data: MediaQueryData(
              size: Size(size.width, 800),
              padding: const EdgeInsets.fromLTRB(12, 24, 20, 0),
              textScaler: TextScaler.linear(size.scale),
            ),
            child: Scaffold(
              body: ArtistIdentity(
                artistName: 'Original_漢字_Tag',
                banner: banner,
              ),
            ),
          ),
        );
        final menu = tester.getRect(find.byType(KurumiPopupMenuButton));
        final back = tester.getRect(find.byType(BackButton));
        final follow = tester.getRect(find.text('Follow'));
        expect(menu.right, closeTo(size.width - 20 - 8, .1));
        expect(back.left, closeTo(12 + 8, .1));
        expect(follow.right, lessThanOrEqualTo(menu.left));
        expect(menu.left - follow.right, lessThan(24));
        expect(back.right, lessThan(follow.left));
        expect(menu.top, greaterThanOrEqualTo(24));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Copy Artist Tag copies the unmodified tag and gives feedback', (
    tester,
  ) async {
    final harness = FollowingTopicHarness();
    addTearDown(harness.dispose);
    final banner = ArtistBannerSnapshot();
    addTearDown(banner.dispose);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await harness.pump(
      tester,
      Scaffold(
        body: ArtistIdentity(artistName: 'Original_漢字_Tag', banner: banner),
      ),
    );
    await tester.tap(find.byType(KurumiPopupMenuButton));
    await tester.pumpAndSettle();
    expect(find.text('Copy Artist Tag'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    await tester.tap(find.text('Copy Artist Tag'));
    await tester.pumpAndSettle();
    expect(copied, 'Original_漢字_Tag');
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(KurumiDurations.shortToast);
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsNothing);
  });
}

class _Launcher implements ExternalUrlLauncher {
  final urls = <Uri>[];
  @override
  Future<bool> launch(
    Uri url, {
    ExternalLaunchMode mode = ExternalLaunchMode.externalApplication,
  }) async {
    urls.add(url);
    return true;
  }
}
