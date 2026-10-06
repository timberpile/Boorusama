import 'package:boorusama/boorus/danbooru/posts/details/providers.dart';
import 'package:boorusama/boorus/e621/posts/providers.dart';
import 'package:boorusama/boorus/e621/downloads/providers.dart';
import 'package:boorusama/boorus/philomena/posts/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/posts/media_preload/providers.dart';
import 'package:boorusama/core/posts/media_preload/types.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_image_preloader.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = _profile(
    BooruType.danbooru,
    'https://one.example',
    PostQuality.medium,
  );
  final second = _profile(
    BooruType.e621,
    'https://two.example',
    PostQuality.high,
  );
  test('quality follows explicit auth independently of selected profile', () {
    final container = _container([first, second]);
    addTearDown(container.dispose);
    expect(
      (container.read(defaultMediaUrlResolverProvider(first.auth))
              as DefaultMediaUrlResolver)
          .postQuality,
      PostQuality.medium,
    );
    expect(
      (container.read(defaultMediaUrlResolverProvider(second.auth))
              as DefaultMediaUrlResolver)
          .postQuality,
      PostQuality.high,
    );
    final missing = _profile(
      BooruType.philomena,
      'https://missing.example',
      PostQuality.medium,
    );
    expect(
      (container.read(defaultMediaUrlResolverProvider(missing.auth))
              as DefaultMediaUrlResolver)
          .postQuality,
      PostQuality.high,
    );
    expect(
      (container.read(defaultMediaUrlResolverProvider(first.auth))
              as DefaultMediaUrlResolver)
          .postQuality,
      PostQuality.medium,
    );
  });
  test('disabled and ambiguous matching profiles use global quality', () {
    final disabled = first.copyWith(
      viewerConfigs: () => first.viewerConfigs!.copyWith(enable: false),
    );
    final container = _container([
      disabled,
      second,
      second.copyWith(name: 'duplicate'),
    ]);
    addTearDown(container.dispose);
    expect(
      (container.read(defaultMediaUrlResolverProvider(disabled.auth))
              as DefaultMediaUrlResolver)
          .postQuality,
      PostQuality.high,
    );
    expect(
      (container.read(defaultMediaUrlResolverProvider(second.auth))
              as DefaultMediaUrlResolver)
          .postQuality,
      PostQuality.high,
    );
  });
  test(
    'explicit engine providers select post media while grid quality and download selection remain independent',
    () async {
      final philomena = _profile(
        BooruType.philomena,
        'https://three.example',
        PostQuality.medium,
      );
      final container = _container([first, second, philomena]);
      addTearDown(container.dispose);
      final resolutions = [
        (
          first,
          container.read(danbooruMediaUrlResolverProvider(first.auth)),
          '${first.url}/thumb',
        ),
        (
          second,
          container.read(e621MediaUrlResolverProvider(second.auth)),
          '${second.url}/sample',
        ),
        (
          philomena,
          container.read(philomenaMediaUrlResolverProvider(philomena.auth)),
          '${philomena.url}/sample',
        ),
      ];
      for (final (profile, resolver, expected) in resolutions) {
        final post = _post(profile);
        expect(resolver.resolveMediaUrl(post, profile.viewer), expected);
        expect(
          container
              .read(gridThumbnailUrlGeneratorProvider(profile.auth))
              .resolve(
                post,
                settings: container.read(
                  gridThumbnailSettingsProvider(profile.auth),
                ),
              )
              .url,
          '${profile.url}/sample',
        );
        expect(
          (await const UrlInsidePostExtractor().getDownloadFileUrl(
            post: post,
            quality: 'original',
          ))!.url,
          '${profile.url}/original',
        );
      }
      final post = _post(second);
      final resolver = container.read(
        e621MediaUrlResolverProvider(second.auth),
      );
      expect(resolver.resolveMediaAspectRatio(post, second.viewer), 0.5);
      final override = BooruConfig.fromJson({
        ...second.toJson(),
        'id': '00000000-0000-4000-8000-000000000001',
        'imageDetaisQuality': 'preview',
      });
      expect(
        resolver.resolveMediaUrl(post, override.viewer),
        '${second.url}/thumb',
      );
      expect(resolver.resolveMediaAspectRatio(post, override.viewer), 1);
      expect(
        resolver.resolveMediaUrl(_post(second, format: 'gif'), override.viewer),
        '${second.url}/sample',
      );
      expect(
        resolver.resolveVideoUrl(_post(second, format: 'mp4'), second.viewer),
        '${second.url}/video',
      );
      expect(
        resolver.resolveMediaUrl(_post(second, format: 'mp4'), second.viewer),
        '${second.url}/poster',
      );
      expect(
        (await const E621DownloadFileUrlExtractor().getDownloadFileUrl(
          post: post,
          quality: 'preview',
        ))!.url,
        '${second.url}/thumb',
      );
    },
  );

  testWidgets(
    'mixed preloads match auth quality and skip explicit original overrides',
    (
      tester,
    ) async {
      final highest = _profile(
        BooruType.philomena,
        'https://three.example',
        PostQuality.high,
      );
      final profiles = [
        first,
        BooruConfig.fromJson({
          ...second.toJson(),
          'id': '00000000-0000-4000-8000-000000000002',
          'imageDetaisQuality': 'original',
        }),
        highest,
      ];
      final calls = <(BooruConfigAuth, String)>[];
      final managers = <PreloadManager>[];
      final container = ProviderContainer(
        overrides: [
          initialSettingsBooruConfigProvider.overrideWithValue(first),
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          settingsProvider.overrideWithValue(
            Settings.defaultSettings.copyWith(
              listing: Settings.defaultSettings.listing.copyWith(
                imageQuality: ImageQuality.low,
              ),
            ),
          ),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: profiles),
          ),
          booruRepoProvider.overrideWith((ref, config) => null),
          dioForWidgetProvider.overrideWith((ref, config) => Dio()),
          preloadManagerProvider.overrideWith((ref, params) {
            final manager = PreloadManager(
              preloader: (url, token) async {
                calls.add((params.authConfig, url));
              },
            );
            managers.add(manager);
            return manager;
          }),
        ],
      );
      final pages = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 4,
        checkIfLargeScreen: () => false,
      );
      addTearDown(() {
        pages.dispose();
        for (final manager in managers) {
          manager.dispose();
        }
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PostDetailsPageViewScope(
              controller: pages,
              child: MixedPostDetailsImagePreloader(
                posts: [
                  _post(first),
                  _post(first),
                  _post(second),
                  _post(highest),
                ],
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      pages.currentPage.value = 1;
      await tester.pumpAndSettle();
      pages.currentPage.value = 2;
      await tester.pumpAndSettle();
      expect(calls, contains((second.auth, '${second.url}/thumb')));
      expect(calls, contains((highest.auth, '${highest.url}/sample')));
      expect(calls.where((entry) => entry.$2.endsWith('/original')), isEmpty);
      expect(calls.every((entry) => entry.$2.startsWith(entry.$1.url)), isTrue);
      expect(
        calls,
        contains((first.auth, '${first.url}/sample')),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

ProviderContainer _container(List<BooruConfig> profiles) => ProviderContainer(
  overrides: [
    initialSettingsBooruConfigProvider.overrideWithValue(profiles.first),
    settingsProvider.overrideWithValue(
      Settings.defaultSettings.copyWith(
        listing: Settings.defaultSettings.listing.copyWith(
          imageQuality: ImageQuality.high,
        ),
      ),
    ),
    booruConfigProvider.overrideWith(
      () => BooruConfigNotifier(initialConfigs: profiles),
    ),
    booruRepoProvider.overrideWith((ref, config) => null),
  ],
);
BooruConfig _profile(BooruType type, String url, PostQuality quality) =>
    BooruConfig.defaultConfig(
      booruType: type,
      url: url,
      customDownloadFileNameFormat: null,
    ).copyWith(
      viewerConfigs: () => ViewerConfigs(
        settings: Settings.defaultSettings.viewer.copyWith(
          postQuality: quality,
        ),
        enable: true,
      ),
    );

Post _post(BooruConfig profile, {String format = 'png'}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.fromLegacyId(profile.booruId),
    booruId: profile.booruId,
    source: profile.url,
  ),
  core: PostCoreData(
    id: 1,
    thumbnailImageUrl: '${profile.url}/thumb',
    sampleImageUrl: '${profile.url}/sample',
    originalImageUrl: '${profile.url}/original',
    videoUrl: '${profile.url}/video',
    videoThumbnailUrl: '${profile.url}/poster',
    width: 200,
    height: 400,
    format: format,
    md5: '',
    fileSize: 100,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    thumbnailAspectRatio: 1,
    sampleAspectRatio: 0.5,
    originalAspectRatio: 0.5,
  ),
  booruData: const EmptyPostData(typeKey: 'fixture'),
);
