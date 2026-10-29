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
import '../developer_options/providers.dart';
import '../http/client/providers.dart';
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
    final network = ref.watch(networkSettingsProvider(config));
    final headers = ref.watch(httpHeadersProvider(config));
    final dio = ref.watch(dioForWidgetProvider(config));
    final overrideDio = ref.watch(mediaOverrideDioProvider(config));
    final manager =
        imageCacheManager ?? ref.watch(defaultImageCacheManagerProvider);
    final platform = Kurumi.themeOf(context).platform;
    final androidVersion = ref
        .watch(deviceInfoProvider)
        .androidDeviceInfo
        ?.version
        .sdkInt;
    final identity = (
      config,
      urls.join('\n'),
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
        history.remove(identity);
        if (index == null) return;
        if (history.length >= 256) history.remove(history.keys.first);
        history[identity] = index;
      },
      candidates: [
        for (final url in urls)
          () {
            final request = network.resolveMedia(url, headers: headers);
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
