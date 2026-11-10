import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/content_media_dio.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_item.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../support/fakes/test_post.dart';
import '../posts/details/progressive_image_test_utils.dart' as helpers;

const _site = 'https://safebooru.donmai.us';
const _image = '$_site/image.png';
final _context = StateProvider<ContentAccessContext?>((ref) => null);

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
  void block() => state = AsyncData(
    [
      BlacklistedTag(
        id: 1,
        name: 'blocked_tag',
        isActive: true,
        createdDate: DateTime.utc(2026),
        updatedDate: DateTime.utc(2026),
      ),
    ].lock,
  );
  void ready() => state = AsyncData(<BlacklistedTag>[].lock);
  void loading() => state = const AsyncLoading();
}

BooruConfig _profile({String? excludedRating}) => BooruConfig.fromJson({
  ...BooruConfig.empty.toJson(),
  'id': '11111111-1111-4111-8111-111111111111',
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
  'url': _site,
  'ratingFilter': excludedRating == null
      ? BooruConfigRatingFilter.none.index
      : BooruConfigRatingFilter.custom.index,
  if (excludedRating != null) 'granularRatingFilterString': excludedRating,
});

void main() {
  for (final viewer in [false, true]) {
    testWidgets(
      'cached ${viewer ? 'viewer' : 'cover'} obeys public blacklist before decoding',
      (tester) async {
        final source = const AnonymousSourcePolicy().resolve(
          BooruType.danbooru,
          Uri.parse(_site),
        )!;
        final key = ContentAccessKey(
          engine: source.engine,
          siteNamespace: source.site.host,
          authEpoch: 1,
          policyEpoch: 1,
        );
        final scope = AnonymousReadScope(
          source: source,
          key: key,
          createDio: () => throw StateError('Unexpected transport'),
          current: () => true,
        );
        addTearDown(scope.dispose);
        final config = _profile().copyWith(anonymousReadScope: scope);
        final access = ContentAccessContext.anonymous(
          config: config,
          scope: scope,
        );
        final cache = helpers.TestImageCache({_image: helpers.targetPng});
        final adapter = helpers.ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWithValue(Settings.defaultSettings),
            automaticMediaLoadingEnabledProvider.overrideWithValue(true),
            globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
            contentAccessContextProvider.overrideWith((ref, key) => access),
            dioForWidgetProvider.overrideWith((ref, auth) => dio),
            contentMediaDioProvider.overrideWith((ref, key) => dio),
            defaultImageCacheManagerProvider.overrideWithValue(cache),
            imageListingSettingsProvider.overrideWithValue(
              Settings.defaultSettings.listing,
            ),
            httpHeadersProvider.overrideWith((ref, auth) => const {}),
            deviceInfoProvider.overrideWithValue(const DeviceInfo()),
          ],
        );
        addTearDown(container.dispose);
        final post = TestPost(
          id: 1,
          tags: {'blocked_tag'},
          originalImageUrl: _image,
          thumbnailImageUrl: _image,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: helpers.testApp(
              viewer
                  ? ProgressivePostImage(
                      post: post,
                      mediaIdentity: 1,
                      config: config.auth,
                      imageUrl: _image,
                      lowerMedia: const GridThumbnailMedia(
                        url: _image,
                        aspectRatio: 1,
                      ),
                      aspectRatio: 1,
                      geometryAspectRatio: 1,
                      imageCacheManager: cache,
                    )
                  : PostGridImage(
                      post: post,
                      config: config.auth,
                      media: const GridThumbnailMedia(
                        url: _image,
                        aspectRatio: 1,
                      ),
                      imageCacheManager: cache,
                    ),
            ),
          ),
        );
        await tester.runAsync(
          () => helpers.waitForPixel(tester, [0, 0, 255, 255]),
        );
        final blacklist = container.read(
          globalBlacklistedTagsProvider.notifier,
        ) as _Blacklist;
        blacklist.block();
        await tester.pump();
        expect(find.byType(BooruRawImage), findsNothing);
        expect(find.byType(RawProgressivePostImage), findsNothing);
        blacklist.loading();
        await tester.pump();
        expect(find.byType(BooruRawImage), findsNothing);
        expect(find.byType(RawProgressivePostImage), findsNothing);
        blacklist.ready();
        await tester.pump();
        await tester.runAsync(
          () => helpers.waitForPixel(tester, [0, 0, 255, 255]),
        );
        expect(cache.bytes[_image], helpers.targetPng);
        expect(adapter.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cached bound cover applies custom rating exclusions while unbound Browse keeps its controls',
    (tester) async {
      final cache = helpers.TestImageCache({_image: helpers.targetPng});
      ContentAccessContext access(String? excluded) =>
          ContentAccessContext.profile(
            config: _profile(excludedRating: excluded),
            authEpoch: 1,
            policyEpoch: 1,
          );
      final adapter = helpers.ControlledImageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final container = ProviderContainer(
        overrides: [
          _context.overrideWith((ref) => access(null)),
          settingsProvider.overrideWithValue(Settings.defaultSettings),
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          contentAccessContextProvider.overrideWith(
            (ref, key) => ref.watch(_context),
          ),
          contentEffectiveBlacklistProvider.overrideWith(
            (ref, id) => const AsyncData(<String>{}),
          ),
          dioForWidgetProvider.overrideWith((ref, auth) => dio),
          contentMediaDioProvider.overrideWith((ref, key) => dio),
          defaultImageCacheManagerProvider.overrideWithValue(cache),
          imageListingSettingsProvider.overrideWithValue(
            Settings.defaultSettings.listing,
          ),
          httpHeadersProvider.overrideWith((ref, auth) => const {}),
          deviceInfoProvider.overrideWithValue(const DeviceInfo()),
        ],
      );
      addTearDown(container.dispose);
      final post = TestPost(
        id: 1,
        originalImageUrl: _image,
        thumbnailImageUrl: _image,
      );
      Widget image() => PostGridImage(
        post: post,
        config: _profile().auth,
        media: const GridThumbnailMedia(url: _image, aspectRatio: 1),
        imageCacheManager: cache,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(
            ProviderScope(
              overrides: [
                currentContentAccessKeyProvider.overrideWithValue(
                  access(null).key,
                ),
              ],
              child: image(),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => helpers.waitForPixel(tester, [0, 0, 255, 255]),
      );
      container.read(_context.notifier).state = access('g');
      await tester.pump();
      expect(find.byType(BooruRawImage), findsNothing);
      container.read(_context.notifier).state = access('e');
      await tester.pump();
      await tester.runAsync(
        () => helpers.waitForPixel(tester, [0, 0, 255, 255]),
      );
      container.read(_context.notifier).state = access('g');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: helpers.testApp(image()),
        ),
      );
      await tester.runAsync(
        () => helpers.waitForPixel(tester, [0, 0, 255, 255]),
      );
      expect(adapter.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
