// Package imports:
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../configs/config/types.dart';
import '../../content/content_access.dart';
import '../../content/content_access_provider.dart';
import '../../content/content_media_access.dart';
import '../../content/content_media_dio.dart';
import '../../configs/network/providers.dart';
import '../../developer_options/providers.dart';
import '../../http/client/providers.dart';
import '../../images/providers.dart';
import 'types.dart';

final preloadManagerProvider =
    Provider.family<PreloadManager, ({Dio dio, BooruConfigAuth authConfig})>(
      (ref, params) {
        final cacheManager = ref.watch(defaultImageCacheManagerProvider);
        final imagePreloader = ImagePreloader(
          cacheManager: cacheManager,
          dio: params.dio,
        );
        final headers = ref.watch(httpHeadersProvider(params.authConfig));

        final network = ref.watch(networkSettingsProvider(params.authConfig));
        ProviderSubscription<Dio>? overrideTransport;
        ImagePreloader overridePreloader() {
          overrideTransport ??= ref.listen(
            mediaOverrideDioProvider(params.authConfig),
            (_, _) {},
          );
          return ImagePreloader(
            cacheManager: cacheManager,
            dio: overrideTransport!.read(),
          );
        }

        final manager = PreloadManager(
          preloader: (url, cancelToken) {
            final request = network.resolveMedia(
              url,
              headers: headers,
              sourceUrl: params.authConfig.url,
            );
            return (request.overridden ? overridePreloader() : imagePreloader)
                .preloadImage(
                  request.url,
                  headers: request.headers,
                  cancelToken: cancelToken,
                  propagateErrors: true,
                );
          },
          downloadConfiguration: const DownloadConfiguration(),
          isEnabled: () => ref.read(automaticMediaLoadingEnabledProvider),
        );

        ref.listen(automaticMediaLoadingEnabledProvider, (_, enabled) {
          if (!enabled) manager.cancelAll();
        });

        ref.onDispose(() {
          manager.dispose();
          overrideTransport?.close();
        });

        return manager;
      },
    );

typedef ContentPreloadRequest = ({
  BooruConfigAuth auth,
  ContentAccessKey access,
});

/// Source-bound preload work owns a subscription only for its bounded window.
final contentPreloadManagerProvider = Provider.autoDispose
    .family<PreloadManager, ContentPreloadRequest>(_createContentPreloader);

/// Independent viewport ownership prevents one Work from cancelling another
/// occurrence's speculative requests while both share the existing HTTP/cache.
final contentOccurrencePreloadManagerProvider = Provider.autoDispose
    .family<
      PreloadManager,
      ({ContentPreloadRequest source, Object occurrence})
    >(
      (ref, request) => _createContentPreloader(ref, request.source),
    );

PreloadManager _createContentPreloader(Ref ref, ContentPreloadRequest request) {
  final context = ref.watch(contentAccessContextProvider(request.access));
  final delegate = ref.watch(defaultImageCacheManagerProvider);
  final cache = ref.watch(
    contentMediaCacheManagerProvider((
      manager: delegate,
      access: request.access,
    )),
  );
  final valid = context != null && context.config?.auth == request.auth;
  final publicScope = request.auth.anonymousReadScope;
  final dio = valid ? ref.watch(contentMediaDioProvider(request.access)) : null;

  final headers = valid
      ? ref.watch(httpHeadersProvider(request.auth))
      : const <String, String>{};
  final network = ref.watch(networkSettingsProvider(request.auth));
  bool current() =>
      valid &&
      (publicScope?.isCurrent ?? true) &&
      ref.read(contentAccessContextProvider(request.access))?.key ==
          request.access;
  final manager = PreloadManager(
    isEnabled: () =>
        current() && ref.read(automaticMediaLoadingEnabledProvider),
    preloader: (url, token) async {
      if (!current()) return;
      final uri = Uri.tryParse(url);
      if (publicScope != null &&
          (uri == null || !publicScope.source.allowsMedia(uri))) {
        return;
      }
      final media = network.resolveMedia(
        url,
        headers: headers,
        sourceUrl: request.auth.url,
      );
      await ImagePreloader(
        cacheManager: cache,
        dio: dio!,
      ).preloadImage(
        media.url,
        headers: media.headers,
        cancelToken: token,
        propagateErrors: true,
      );
    },
  );
  ref.listen(automaticMediaLoadingEnabledProvider, (_, enabled) {
    if (!enabled) manager.cancelAll();
  });
  ref.onDispose(manager.dispose);
  return manager;
}
