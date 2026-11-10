import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_dio.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../support/fakes/test_post.dart';
import '../posts/details/progressive_image_test_utils.dart' as helpers;

class _Blacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
}

void main() {
  testWidgets(
    'retained Realbooru original decodes above its thumbnail across public scopes',
    (tester) async {
      const original = 'https://realbooru.com//images/ab/cd/saved.png';
      const thumbnail =
          'https://realbooru.com/thumbnails/ab/cd/thumbnail_saved.jpg';
      final source = const AnonymousSourcePolicy().resolve(
        BooruType.gelbooruV2,
        Uri.parse('https://realbooru.com'),
      )!;
      final post = TestPost(
        id: 42,
        originalImageUrl: original,
        thumbnailImageUrl: thumbnail,
        origin: PostOrigin.fromSource(
          booruType: source.engine,
          booruId: source.engine.id,
          source: source.site.toString(),
        ),
        booruData: const LegacyPostData(
          typeKey: 'legacy_gelbooruV2',
          custom: {},
        ),
      );
      final cache = helpers.TestImageCache({
        original: helpers.originalPng,
        thumbnail: helpers.lowerPng,
      });
      for (final epoch in [1, 100]) {
        final key = ContentAccessKey(
          engine: source.engine,
          siteNamespace: source.site.host,
          authEpoch: epoch,
          policyEpoch: epoch,
        );
        final scope = AnonymousReadScope(
          source: source,
          key: key,
          createDio: () => throw StateError('Unexpected API request'),
          current: () => true,
        );
        final config = BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': '11111111-1111-4111-8111-111111111111',
          'booruId': source.engine.id,
          'booruIdHint': source.engine.id,
          'url': source.site.toString(),
        }).copyWith(anonymousReadScope: scope);
        final access = ContentAccessContext.anonymous(
          config: config,
          scope: scope,
        );
        final adapter = helpers.ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final container = ProviderContainer(
          overrides: [
            globalBlacklistedTagsProvider.overrideWith(_Blacklist.new),
            contentAccessContextProvider.overrideWith((ref, key) => access),
            automaticMediaLoadingEnabledProvider.overrideWithValue(true),
            settingsProvider.overrideWithValue(Settings.defaultSettings),
            imageListingSettingsProvider.overrideWithValue(
              Settings.defaultSettings.listing,
            ),
            deviceInfoProvider.overrideWithValue(const DeviceInfo()),
            httpHeadersProvider.overrideWith((ref, auth) => const {}),
            defaultImageCacheManagerProvider.overrideWithValue(cache),
            dioForWidgetProvider.overrideWith((ref, auth) => dio),
            contentMediaDioProvider.overrideWith((ref, key) => dio),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: helpers.testApp(
                ProgressivePostImage(
                  post: post,
                  mediaIdentity: 42,
                  config: config.auth,
                  imageUrl: original,
                  lowerMedia: const GridThumbnailMedia(
                    url: thumbnail,
                    aspectRatio: 1,
                  ),
                  aspectRatio: 1,
                  geometryAspectRatio: 1,
                  imageCacheManager: cache,
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => helpers.waitForPixel(tester, [0, 255, 0, 255]),
          );
          expect(adapter.requests, isEmpty);
          expect(cache.bytes.keys, contains(original));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          scope.dispose();
          dio.close(force: true);
        }
      }
    },
  );
}
