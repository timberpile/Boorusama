import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/network/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/media_preload/providers.dart';
import 'package:boorusama/core/posts/media_preload/types.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../core/posts/details/progressive_image_test_utils.dart';

void main() {
  final config = BooruConfig.empty.copyWith(
    url: 'https://source.test',
    networkSettings: () => NetworkSettings(
      mediaHostOverrides: [
        MediaHostOverride(from: 'source.test', to: 'cdn.test'),
      ],
    ),
  );

  testWidgets(
    'viewer and preloader resolve replacements without source credentials',
    (tester) async {
      final source = ControlledImageAdapter();
      final destination = ControlledImageAdapter();
      final sourceDio = Dio()..httpClientAdapter = source;
      final mediaDio = Dio()..httpClientAdapter = destination;
      final cache = TestImageCache({});
      final container = ProviderContainer(
        overrides: [
          dioForWidgetProvider(config.auth).overrideWithValue(sourceDio),
          mediaOverrideDioProvider(config.auth).overrideWithValue(mediaDio),
          httpHeadersProvider(config.auth).overrideWithValue({
            'Authorization': 'private',
            'Cookie': 'private',
            'Referer': 'https://source.test/private',
            'User-Agent': 'fixture',
          }),
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          defaultImageCacheManagerProvider.overrideWithValue(cache),
          deviceInfoProvider.overrideWithValue(const DeviceInfo()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(
            ProgressivePostImage(
              mediaIdentity: 'image',
              config: config.auth,
              imageUrl: 'https://source.test/target.png',
              lowerMedia: const GridThumbnailMedia(
                url: 'https://source.test/lower.png',
                aspectRatio: 1,
              ),
              aspectRatio: 1,
              geometryAspectRatio: 1,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => destination.requests.length == 2,
          reason: 'viewer replacement requests',
        ),
      );
      expect(source.requests, isEmpty);
      expect(destination.requests.map((request) => request.uri.host).toSet(), {
        'cdn.test',
      });
      for (final request in destination.requests) {
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(
            anyOf(
              contains('authorization'),
              contains('cookie'),
              contains('referer'),
            ),
          ),
        );
      }
      destination.complete('https://cdn.test/lower.png', lowerPng);
      destination.complete('https://cdn.test/target.png', targetPng);
      await tester.runAsync(() => waitForPixel(tester, [0, 0, 255, 255]));

      final manager = container.read(
        preloadManagerProvider((dio: sourceDio, authConfig: config.auth)),
      );
      manager.preloadMedias(
        const PreloadResult(
          prioritizedUrls: [
            PrioritizedUrl(
              url: 'https://source.test/next.png',
              priority: 1,
              distance: 1,
              relevanceZone: RelevanceZone.nearby,
            ),
          ],
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => destination.pending.containsKey('https://cdn.test/next.png'),
          reason: 'preload replacement request',
        ),
      );
      expect(source.requests, isEmpty);
      expect(
        destination.requests.last.headers.keys.map((key) => key.toLowerCase()),
        isNot(
          anyOf(
            contains('authorization'),
            contains('cookie'),
            contains('referer'),
          ),
        ),
      );
      destination.complete('https://cdn.test/next.png', targetPng);
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => manager.state.activeDownloads.isEmpty,
          reason: 'completed preload',
        ),
      );
      expect(cache.bytes, contains('https://cdn.test/next.png'));
      await tester.pumpWidget(const SizedBox());
      sourceDio.close(force: true);
      mediaDio.close(force: true);
    },
  );
}
