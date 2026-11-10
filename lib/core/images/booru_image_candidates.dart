import 'dart:convert';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../foundation/info/device_info.dart';
import '../configs/config/types.dart';
import '../configs/network/providers.dart';
import '../content/content_media_access.dart';
import '../content/content_media_dio.dart';
import '../content/content_media_failures.dart';
import '../developer_options/providers.dart';
import '../http/client/providers.dart';
import '../posts/details/src/types/post_presentation_fallback_reason.dart';
import 'booru_image.dart' show ErrorPlaceholder;
import 'image_candidate_picker.dart';
import 'providers.dart';

final _candidateHistoryProvider = Provider((ref) => <Object, int>{});

/// Grid-only opt-in. Existing providers retain authentication, media overrides,
/// cache leases and platform-specific decoders (including AVIF).
class BooruImageCandidates extends ConsumerWidget {
  const BooruImageCandidates({
    required this.config,
    required this.urls,
    required this.placeholder,
    required this.builder,
    this.imageCacheManager,
    super.key,
  });

  final BooruConfigAuth config;
  final List<String> urls;
  final Widget placeholder;
  final Widget Function(ImageProvider image) builder;
  final ImageCacheManager? imageCacheManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(automaticMediaLoadingEnabledProvider)) return placeholder;
    final access = watchContentMediaAccess(ref, config);
    if (!access.allowed) return placeholder;
    final publicSource = config.anonymousReadScope?.source;
    final allowedUrls = publicSource == null
        ? urls
        : urls.where((url) {
            final uri = Uri.tryParse(url);
            return uri != null && publicSource.allowsMedia(uri);
          }).toList();
    if (allowedUrls.isEmpty) {
      return publicSource == null
          ? placeholder
          : const ErrorPlaceholder(
              reason: PostPresentationFallbackReason.unavailableEngine,
            );
    }
    final network = ref.watch(networkSettingsProvider(config));
    final headers = ref.watch(httpHeadersProvider(config));
    final dio = access.key == null
        ? ref.watch(dioForWidgetProvider(config))
        : ref.watch(contentMediaDioProvider(access.key!));
    final needsOverride = allowedUrls.any(
      (url) => network
          .resolveMedia(url, headers: headers, sourceUrl: config.url)
          .overridden,
    );
    final overrideDio = needsOverride && access.key == null
        ? ref.watch(mediaOverrideDioProvider(config))
        : dio;
    final fallbackManager = ref.watch(defaultImageCacheManagerProvider);
    final delegate = imageCacheManager ?? fallbackManager;
    final manager = access.key == null
        ? delegate
        : ref.watch(
            contentMediaCacheManagerProvider((
              manager: delegate,
              access: access.key!,
            )),
          );
    final platform = Kurumi.themeOf(context).platform;
    final androidVersion = ref
        .watch(deviceInfoProvider)
        .androidDeviceInfo
        ?.version
        .sdkInt;
    final identity = (
      config,
      allowedUrls.join('\n'),
      network,
      jsonEncode(headers),
      manager,
      platform,
      androidVersion,
    );
    final history = ref.watch(_candidateHistoryProvider);
    return ImageCandidatePicker(
      key: ValueKey(identity),
      preferredIndex: history[identity],
      placeholder: placeholder,
      builder: builder,
      onSelected: (index) {
        reportContentMediaOutcome(context, failed: index == null);
        history.remove(identity);
        if (index == null) return;
        if (history.length >= 256) history.remove(history.keys.first);
        history[identity] = index;
      },
      candidates: [
        for (final url in allowedUrls)
          () {
            final request = network.resolveMedia(
              url,
              headers: headers,
              sourceUrl: config.url,
            );
            final token = CancelToken();
            return ImageCandidate(
              image: ExtendedImage.network(
                request.url,
                dio: request.overridden ? overrideDio : dio,
                headers: request.headers,
                cancelToken: token,
                cacheManager: manager,
                platform: platform,
                androidVersion: androidVersion,
                printError: false,
                fetchStrategy: const FetchStrategyBuilder(silent: true),
              ).image,
              cancel: () => token.cancel('Thumbnail probe no longer needed'),
            );
          },
      ],
    );
  }
}
