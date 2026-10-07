import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kurumi/kurumi.dart';
import 'package:like_button/like_button.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/haptics/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/post/src/widgets/image_overlay_icon.dart';
import 'package:boorusama/core/posts/post/src/widgets/thumbnail_overlay.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:boorusama/core/videos/player/widgets.dart';
import 'package:boorusama/core/widgets/website_logo.dart';

import '../details/progressive_image_test_utils.dart' as images;

void main() {
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterRoot = configFile.absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../');
    await (FontLoader('Roboto')..addFont(
          File.fromUri(
            flutterRoot.resolve(
              'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    for (final font in [
      (
        family: 'packages/material_symbols_icons/MaterialSymbolsOutlined',
        asset:
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
      ),
      (
        family: 'packages/material_symbols_icons/MaterialSymbolsRounded',
        asset:
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
      ),
      (
        family: 'packages/font_awesome_flutter/FontAwesomeSolid',
        asset:
            'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
      ),
    ]) {
      await (FontLoader(
        font.family,
      )..addFont(rootBundle.load(font.asset))).load();
    }
  });

  for (final width in [80.0, 120.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('all badges fit a $width pixel tile at text scale $scale', (
        tester,
      ) async {
        for (final media in [
          (gif: true, duration: null, sound: null),
          (gif: false, duration: null, sound: null),
          (gif: false, duration: 12.0, sound: true),
          (gif: false, duration: 360000.0, sound: false),
        ]) {
          await tester.pumpWidget(
            _app(
              _tile(
                width: width,
                gif: media.gif,
                duration: media.duration,
                sound: media.sound,
              ),
              scale: scale,
            ),
          );
          expect(tester.takeException(), isNull);
          for (final badge in find.byType(ImageOverlayIcon).evaluate()) {
            expect(
              tester.getSize(find.byWidget(badge.widget)),
              const Size(20, 20),
            );
          }
          if (media.duration != null) {
            final size = tester.getSize(find.byType(VideoPlayDurationIcon));
            expect(size.height, 20);
            expect(size.width, lessThanOrEqualTo(width - 5));
            expect(size.width, greaterThan(20));
            final sound = media.sound!
                ? Symbols.volume_up_rounded
                : Symbols.volume_off_rounded;
            expect(tester.getSize(find.byIcon(sound)), const Size(16, 16));
          }
          expect(
            tester.getSize(find.byType(ThumbnailOverlayBox)),
            const Size(20, 20),
          );
          final ai = find
              .ancestor(of: find.text('AI'), matching: find.byType(Container))
              .first;
          expect(tester.getSize(ai).height, 20);
        }
      });
    }
  }

  testWidgets(
    'profile and network logo states stay inside the thumbnail area',
    (tester) async {
      final adapter = images.ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final cache = images.TestImageCache({
        'https://icons.test/custom.png': images.portraitPng,
      });
      for (final logo in [
        ConfigAwareWebsiteLogo.fromBooruType(
          BooruType.danbooru,
          'https://danbooru.donmai.us',
        ),
        ConfigAwareWebsiteLogo.fromBooruType(
          BooruType.hydrus,
          'http://localhost',
        ),
        const ConfigAwareWebsiteLogo(url: null),
        const ConfigAwareWebsiteLogo(
          url: null,
          customIconUrl: 'https://icons.test/custom.png',
          fit: BoxFit.contain,
        ),
        const ConfigAwareWebsiteLogo(
          url: null,
          customIconUrl: 'https://icons.test/pending.png',
        ),
      ]) {
        await tester.pumpWidget(
          _app(
            _tile(leading: logo),
            dio: dio,
            cache: cache,
          ),
        );
        await images.decodePump(tester);
        expect(
          tester.getSize(find.byType(ThumbnailOverlayBox)),
          const Size(20, 20),
        );
        expect(tester.takeException(), isNull);
        if (logo.customIconUrl?.endsWith('pending.png') ?? false) {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          adapter.complete(
            'https://icons.test/pending.png',
            Uint8List(0),
            status: 404,
          );
          await images.decodePump(tester);
          expect(find.byType(FaIcon), findsOneWidget);
          expect(
            tester.getSize(find.byType(ThumbnailOverlayBox)),
            const Size(20, 20),
          );
          expect(tester.takeException(), isNull);
        }
      }
      // The shared logo defaults outside thumbnails retain their original size.
      await tester.pumpWidget(_app(WebsiteLogo(url: null, dio: dio)));
      expect(tester.getSize(find.byType(WebsiteLogo)), const Size(32, 32));
    },
  );

  testWidgets(
    'transparent favorite padding toggles after async success and leaves the post tappable',
    (tester) async {
      final pending = Completer<void>();
      final toggles = <bool>[];
      var postTaps = 0;
      await tester.pumpWidget(
        _app(
          _tile(
            width: 80,
            onTap: () => postTaps++,
            favorite: QuickFavoriteButton(
              isFaved: false,
              onFavToggle: (value) async {
                toggles.add(value);
                if (value) await pending.future;
              },
            ),
          ),
        ),
      );
      final button = find.byType(QuickFavoriteButton);
      expect(tester.getSize(button), const Size(48, 48));
      final background = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(tester.getSize(background), const Size(24, 24));
      final tileRect = tester.getRect(find.byType(ImageGridItem));
      final backgroundRect = tester.getRect(background);
      expect(tileRect.right - backgroundRect.right, 4);
      expect(tileRect.bottom - backgroundRect.bottom, 4);
      expect(
        tester.getCenter(find.byIcon(Symbols.favorite)),
        backgroundRect.center,
      );
      expect(tester.widget<Icon>(find.byIcon(Symbols.favorite)).size, 20);
      final rect = tester.getRect(button);
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      await tester.pump();
      expect(toggles, [true]);
      expect(
        tester.state<LikeButtonState>(find.byType(LikeButton)).isLiked,
        false,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        tester.state<LikeButtonState>(find.byType(LikeButton)).isLiked,
        true,
      );
      await tester.tapAt(rect.bottomRight - const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(toggles, [true, false]);
      expect(
        tester.state<LikeButtonState>(find.byType(LikeButton)).isLiked,
        false,
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(ImageGridItem)) + const Offset(10, 30),
      );
      expect(postTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an interrupted favorite action keeps its previous state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _tile(
          favorite: QuickFavoriteButton(
            isFaved: true,
            onFavToggle: (_) async => throw DioException(
              requestOptions: RequestOptions(path: '/favorite'),
              type: DioExceptionType.cancel,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(QuickFavoriteButton));
    await tester.pumpAndSettle();
    expect(
      tester.state<LikeButtonState>(find.byType(LikeButton)).isLiked,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures the thumbnail overlay review sheet', (tester) async {
    const path = String.fromEnvironment('POST_010_CAPTURE_PATH');
    final dio = Dio()..httpClientAdapter = images.ControlledImageAdapter();
    addTearDown(() => dio.close(force: true));
    final cache = images.TestImageCache({
      'https://icons.test/custom.png': images.portraitPng,
      'https://icons.test/network.png': images.lowerPng,
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: boundary,
          child: Container(
            color: const Color(0xffeeeeee),
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _sample(
                  'Bundled logo · GIF',
                  _tile(
                    gif: true,
                    leading: ConfigAwareWebsiteLogo.fromBooruType(
                      BooruType.danbooru,
                      'https://danbooru.donmai.us',
                    ),
                  ),
                ),
                _sample(
                  'Custom profile · sound',
                  _tile(
                    duration: 12,
                    sound: true,
                    leading: const ConfigAwareWebsiteLogo(
                      url: null,
                      customIconUrl: 'https://icons.test/custom.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                _sample(
                  'Network logo · silent',
                  _tile(
                    duration: 360000,
                    sound: false,
                    leading: const ConfigAwareWebsiteLogo(
                      url: null,
                      customIconUrl: 'https://icons.test/network.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                _sample(
                  'Fallback · no duration',
                  _tile(leading: const ConfigAwareWebsiteLogo(url: null)),
                ),
                _sample(
                  'Loading · favorite',
                  _tile(
                    leading: const ConfigAwareWebsiteLogo(
                      url: null,
                      customIconUrl: 'https://icons.test/loading.png',
                    ),
                    favorite: const QuickFavoriteButton(isFaved: true),
                  ),
                ),
                _sample(
                  '80 px · text scale 2',
                  MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: _tile(width: 80, duration: 360000, sound: true),
                  ),
                ),
              ],
            ),
          ),
        ),
        dio: dio,
        cache: cache,
      ),
    );
    await images.decodePump(tester);
    expect(tester.takeException(), isNull);
    if (path.isNotEmpty) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.imageCache.clear();
  });
}

Widget _sample(String label, Widget tile) => SizedBox(
  width: 220,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label), const SizedBox(height: 8), tile],
  ),
);

Widget _tile({
  double width = 120,
  bool gif = false,
  double? duration,
  bool? sound,
  Widget? leading,
  Widget? favorite,
  VoidCallback? onTap,
}) => SizedBox(
  width: width,
  child: ImageGridItem(
    image: Container(
      width: width,
      height: 150,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffb5dbe2), Color(0xff638f9a), Color(0xff234b58)],
        ),
      ),
    ),
    onTap: onTap,
    isGif: gif,
    isAnimated: true,
    duration: duration,
    hasSound: sound,
    hasComments: true,
    isTranslated: true,
    hasParentOrChildren: true,
    isAI: true,
    leadingIcons: [
      leading ??
          ConfigAwareWebsiteLogo.fromBooruType(
            BooruType.danbooru,
            'https://danbooru.donmai.us',
          ),
    ],
    quickActionButton: favorite ?? const QuickFavoriteButton(isFaved: false),
  ),
);

Widget _app(
  Widget child, {
  double scale = 1,
  Dio? dio,
  images.TestImageCache? cache,
}) => ProviderScope(
  overrides: [
    automaticMediaLoadingEnabledProvider.overrideWithValue(true),
    hapticFeedbackLevelProvider.overrideWithValue(HapticFeedbackLevel.none),
    faviconDioProvider.overrideWithValue(dio ?? Dio()),
    defaultImageCacheManagerProvider.overrideWithValue(
      cache ?? images.TestImageCache({}),
    ),
  ],
  child: MaterialApp(
    theme: Kurumi.themeFrom(
      KurumiThemeMode.light,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      systemDarkMode: false,
    ).withBoorusamaColors(),
    builder: (context, child) => KurumiTheme(
      data: KurumiThemeData.fromMaterial(Theme.of(context)),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
    home: Scaffold(body: Center(child: child)),
  ),
);
