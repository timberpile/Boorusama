// Package imports:
import 'dart:typed_data';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../foundation/info/device_info.dart';
import '../configs/config/types.dart';
import '../content/content_access.dart';
import '../content/content_media_failures.dart';
import '../configs/network/providers.dart';
import '../content/content_media_access.dart';
import '../content/content_media_dio.dart';
import '../developer_options/blocked_media_placeholder.dart';
import '../developer_options/providers.dart';
import '../http/client/providers.dart';
import '../settings/providers.dart';
import 'image_quality.dart';
import 'providers.dart';

const _defaultRadius = BorderRadius.all(Radius.circular(8));
const _placeholderAspectRatioMismatchThreshold = 0.05;

class BooruImage extends ConsumerWidget {
  const BooruImage({
    required this.imageUrl,
    required this.config,
    super.key,
    this.placeholderUrl,
    this.fallbackUrl,
    this.fallbackUrls = const [],
    this.placeholderAspectRatio,
    this.placeholderFit,
    this.borderRadius,
    this.fit,
    this.aspectRatio = 1,
    this.imageWidth,
    this.imageHeight,
    this.forceCover = false,
    this.forceFill = false,
    this.forceLoadPlaceholder = false,
    this.hideMismatchedPlaceholder = false,
    this.placeholderWidget,
    this.errorWidget,
    this.controller,
    this.imageCacheManager,
    this.cachedImageBytes,
    this.cachedImageAccessKey,
  });

  final BooruConfigAuth config;
  final String imageUrl;
  final String? placeholderUrl;
  final String? fallbackUrl;

  /// Alternate images tried in order before [fallbackUrl].
  final List<String> fallbackUrls;
  final double? placeholderAspectRatio;
  final BoxFit? placeholderFit;
  final BorderRadius? borderRadius;
  final BoxFit? fit;
  final double? aspectRatio;
  final double? imageWidth;
  final double? imageHeight;
  final bool forceCover;
  final bool forceFill;
  final bool forceLoadPlaceholder;
  final bool hideMismatchedPlaceholder;
  final Widget? placeholderWidget;
  final Widget? errorWidget;
  final ExtendedImageController? controller;
  final ImageCacheManager? imageCacheManager;
  final Uint8List? cachedImageBytes;
  final ContentAccessKey? cachedImageAccessKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automaticMediaLoadingEnabled = ref.watch(
      automaticMediaLoadingEnabledProvider,
    );

    if (!automaticMediaLoadingEnabled) {
      return BlockedMediaPlaceholder(
        aspectRatio: forceCover || fit == BoxFit.contain ? null : aspectRatio,
        borderRadius: borderRadius ?? _defaultRadius,
      );
    }

    final access = watchContentMediaAccess(ref, config);
    final publicSource = config.anonymousReadScope?.source;
    bool permitted(String? value) {
      if (value == null || value.isEmpty) return false;
      if (publicSource == null) return true;
      final uri = Uri.tryParse(value);
      return uri != null && publicSource.allowsMedia(uri);
    }

    if (!access.allowed || !permitted(imageUrl)) {
      return NullableAspectRatio(
        aspectRatio: forceCover || fit == BoxFit.contain ? null : aspectRatio,
        child:
            placeholderWidget ??
            KurumiImagePlaceholder(
              borderRadius: borderRadius ?? _defaultRadius,
            ),
      );
    }
    final safePlaceholder = permitted(placeholderUrl) ? placeholderUrl : null;
    final safeFallback = permitted(fallbackUrl) ? fallbackUrl : null;
    final dio = access.key == null
        ? ref.watch(dioForWidgetProvider(config))
        : ref.watch(contentMediaDioProvider(access.key!));
    final network = ref.watch(networkSettingsProvider(config));
    final headers = ref.watch(httpHeadersProvider(config));
    final imageRequest = network.resolveMedia(
      imageUrl,
      headers: headers,
      sourceUrl: config.url,
    );
    final fallbackRequest = network.resolveMedia(
      safeFallback ?? '',
      headers: headers,
      sourceUrl: config.url,
    );
    final placeholderRequest = network.resolveMedia(
      safePlaceholder ?? '',
      headers: headers,
      sourceUrl: config.url,
    );
    final imageQualitySettings = ref.watch(
      imageListingSettingsProvider.select((value) => value.imageQuality),
    );
    final fallbackAspectRatio = ref.watch(
      imageListingSettingsProvider.select(
        (value) => value.imageGridAspectRatio,
      ),
    );
    final deviceInfo = ref.watch(deviceInfoProvider);
    final fallbackCacheManager = ref.watch(
      defaultImageCacheManagerProvider,
    );
    final manager = imageCacheManager ?? fallbackCacheManager;
    final scopedManager = access.key == null
        ? manager
        : ref.watch(
            contentMediaCacheManagerProvider((
              manager: manager,
              access: access.key!,
            )),
          );
    final alternates = fallbackUrls
        .where((url) => permitted(url) && url != imageUrl)
        .toSet()
        .toList();

    return BooruRawImage(
      key: ValueKey((access.key, imageUrl)),
      dio: imageRequest.overridden && access.key == null
          ? ref.watch(mediaOverrideDioProvider(config))
          : dio,
      imageUrl: imageRequest.url,
      placeholderUrl: safePlaceholder == null ? null : placeholderRequest.url,
      placeholderDio:
          safePlaceholder != null &&
              placeholderRequest.overridden &&
              access.key == null
          ? ref.watch(mediaOverrideDioProvider(config))
          : dio,
      placeholderHeaders: placeholderRequest.headers,
      fallbackUrl: safeFallback == null ? null : fallbackRequest.url,
      fallbackDio:
          safeFallback != null &&
              fallbackRequest.overridden &&
              access.key == null
          ? ref.watch(mediaOverrideDioProvider(config))
          : dio,
      fallbackHeaders: fallbackRequest.headers,
      fallbackWidget: alternates.isEmpty
          ? null
          : BooruImage(
              config: config,
              imageUrl: alternates.first,
              fallbackUrls: alternates.skip(1).toList(),
              fallbackUrl: safeFallback,
              placeholderUrl: safePlaceholder,
              placeholderAspectRatio: placeholderAspectRatio,
              placeholderFit: placeholderFit,
              borderRadius: borderRadius,
              fit: fit,
              aspectRatio: aspectRatio,
              imageWidth: imageWidth,
              imageHeight: imageHeight,
              forceCover: forceCover,
              forceFill: forceFill,
              forceLoadPlaceholder: forceLoadPlaceholder,
              hideMismatchedPlaceholder: hideMismatchedPlaceholder,
              placeholderWidget: placeholderWidget,
              errorWidget: errorWidget,
              imageCacheManager: imageCacheManager,
            ),
      placeholderAspectRatio: placeholderAspectRatio,
      placeholderFit: placeholderFit,
      borderRadius: borderRadius,
      fit: fit,
      aspectRatio: aspectRatio ?? fallbackAspectRatio,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      forceCover: forceCover,
      forceFill: forceFill,
      isLargeImage: imageQualitySettings != ImageQuality.low,
      forceLoadPlaceholder: forceLoadPlaceholder,
      hideMismatchedPlaceholder: hideMismatchedPlaceholder,
      headers: imageRequest.headers,
      placeholderWidget: placeholderWidget,
      errorWidget: errorWidget,
      controller: controller,
      androidVersion: deviceInfo.androidDeviceInfo?.version.sdkInt,
      imageCacheManager: scopedManager,
      cachedImageBytes: access.key == null || access.key == cachedImageAccessKey
          ? cachedImageBytes
          : null,
    );
  }
}

class BooruRawImage extends StatelessWidget {
  const BooruRawImage({
    required this.dio,
    required this.imageUrl,
    super.key,
    this.placeholderUrl,
    this.placeholderDio,
    this.placeholderHeaders,
    this.fallbackUrl,
    this.fallbackDio,
    this.fallbackHeaders,
    this.fallbackWidget,
    this.placeholderAspectRatio,
    this.placeholderFit,
    this.borderRadius,
    this.fit,
    this.aspectRatio = 1,
    this.imageWidth,
    this.imageHeight,
    this.forceCover = false,
    this.forceFill = false,
    this.headers = const {},
    this.isLargeImage = false,
    this.forceLoadPlaceholder = false,
    this.hideMismatchedPlaceholder = false,
    this.gaplessPlayback = false,
    this.placeholderWidget,
    this.errorWidget,
    this.controller,
    this.androidVersion,
    this.imageCacheManager,
    this.cachedImageBytes,
  });

  final Dio dio;
  final Dio? placeholderDio;
  final Map<String, String>? placeholderHeaders;
  final String imageUrl;
  final String? placeholderUrl;
  final String? fallbackUrl;
  final Dio? fallbackDio;
  final Map<String, String>? fallbackHeaders;

  /// Displayed on failure before considering [fallbackUrl].
  final Widget? fallbackWidget;
  final double? placeholderAspectRatio;
  final BoxFit? placeholderFit;
  final BorderRadius? borderRadius;
  final BoxFit? fit;
  final double? aspectRatio;
  final double? imageWidth;
  final double? imageHeight;
  final bool forceCover;
  final bool forceFill;
  final Map<String, String> headers;
  final bool isLargeImage;
  final bool forceLoadPlaceholder;
  final bool hideMismatchedPlaceholder;
  final bool gaplessPlayback;
  final Widget? placeholderWidget;
  final Widget? errorWidget;
  final ExtendedImageController? controller;
  final int? androidVersion;
  final ImageCacheManager? imageCacheManager;
  final Uint8List? cachedImageBytes;

  @override
  Widget build(BuildContext context) {
    final imagePlaceHolder = KurumiImagePlaceholder(
      borderRadius: borderRadius ?? _defaultRadius,
    );

    return _ImageRetryControllerScope(
      controller: controller,
      beforeRetry: () async {
        await imageCacheManager?.clearCache(
          imageCacheManager!.generateCacheKey(imageUrl),
        );
      },
      builder: (effectiveController, retry) => _ContentMediaImageState(
        controller: effectiveController,
        child: NullableAspectRatio(
          aspectRatio: forceCover || fit == BoxFit.contain ? null : aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.roundToDouble();
              final height = constraints.maxHeight.roundToDouble();
              final fit =
                  this.fit ??
                  // If the image is larger than the layout, just fill it to prevent distortion
                  (forceFill &&
                          _shouldForceFill(
                            constraints.biggest,
                            imageWidth,
                            imageHeight,
                          )
                      ? BoxFit.fill
                      // Cover is for the standard grid that crops the image to fit the aspect ratio
                      : forceCover
                      ? BoxFit.cover
                      : BoxFit.contain);
              final borderRadius = this.borderRadius ?? _defaultRadius;

              if (cachedImageBytes case final bytes?) {
                return ExtendedImage(
                  image: MemoryImage(bytes),
                  borderRadius: borderRadius,
                  width: width,
                  height: height,
                  fit: fit,
                  controller: effectiveController,
                  placeholderWidget: placeholderWidget ?? imagePlaceHolder,
                  errorWidget: placeholderWidget ?? imagePlaceHolder,
                );
              }

              return imageUrl.isNotEmpty
                  ? ExtendedImage.network(
                      imageUrl,
                      dio: dio,
                      headers: headers,
                      borderRadius: borderRadius,
                      width: width,
                      height: height,
                      fit: fit,
                      gaplessPlayback: gaplessPlayback,
                      fetchStrategy: _fetchStrategy,
                      controller: effectiveController,
                      platform: Kurumi.themeOf(context).platform,
                      androidVersion: androidVersion,
                      cacheManager: imageCacheManager,
                      placeholderWidget:
                          placeholderWidget ??
                          placeholderUrl.toOption().fold(
                            () => imagePlaceHolder,
                            (url) => Builder(
                              builder: (context) {
                                final hasNetworkPlaceholder =
                                    _shouldLoadPlaceholderUrl(
                                      placeholderUrl: url,
                                      imageUrl: imageUrl,
                                      isLargeImage: isLargeImage,
                                      forceLoadPlaceholder:
                                          forceLoadPlaceholder,
                                    );
                                final hasMismatchedPlaceholder =
                                    hideMismatchedPlaceholder &&
                                    _hasAspectRatioMismatch(
                                      placeholderAspectRatio,
                                      aspectRatio,
                                    );

                                return hasNetworkPlaceholder &&
                                        !hasMismatchedPlaceholder
                                    ? _wrapPlaceholderAspectRatio(
                                        ExtendedImage.network(
                                          url,
                                          dio: placeholderDio ?? dio,
                                          headers:
                                              placeholderHeaders ?? headers,
                                          borderRadius: borderRadius,
                                          width: placeholderAspectRatio == null
                                              ? width
                                              : null,
                                          height: placeholderAspectRatio == null
                                              ? height
                                              : null,
                                          fit: placeholderFit ?? fit,
                                          fetchStrategy: _fetchStrategy,
                                          placeholderWidget: imagePlaceHolder,
                                          platform: Kurumi.themeOf(
                                            context,
                                          ).platform,
                                          androidVersion: androidVersion,
                                          cacheManager: imageCacheManager,
                                        ),
                                      )
                                    : imagePlaceHolder;
                              },
                            ),
                          ),
                      errorWidget:
                          errorWidget ??
                          fallbackWidget ??
                          switch (fallbackUrl) {
                            final String url
                                when url.isNotEmpty && url != imageUrl =>
                              _ImageRetryControllerScope(
                                beforeRetry: () async {
                                  await imageCacheManager?.clearCache(
                                    imageCacheManager!.generateCacheKey(url),
                                  );
                                },
                                builder: (fallbackController, retryFallback) =>
                                    ExtendedImage.network(
                                      url,
                                      dio: fallbackDio ?? dio,
                                      controller: fallbackController,
                                      headers: fallbackHeaders ?? headers,
                                      borderRadius: borderRadius,
                                      width: width,
                                      height: height,
                                      fit: fit,
                                      fetchStrategy: _fetchStrategy,
                                      platform: Kurumi.themeOf(context)
                                          .platform,
                                      androidVersion: androidVersion,
                                      cacheManager: imageCacheManager,
                                      placeholderWidget: imagePlaceHolder,
                                      errorWidget: ErrorPlaceholder(
                                        borderRadius: borderRadius,
                                        onRetry: retryFallback,
                                      ),
                                    ),
                              ),
                            _ => ErrorPlaceholder(
                              onRetry: retry,
                              borderRadius: borderRadius,
                            ),
                          },
                    )
                  : imagePlaceHolder;
            },
          ),
        ),
      ),
    );
  }

  Widget _wrapPlaceholderAspectRatio(Widget child) {
    final aspectRatio = placeholderAspectRatio;

    return aspectRatio == null
        ? child
        : Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: SizedBox.expand(
                child: child,
              ),
            ),
          );
  }
}

const _fetchStrategy = FetchStrategyBuilder(
  initialPauseBetweenRetries: Duration(milliseconds: 500),
  // Nothing we can do about it, just ignore the error to avoid spamming the logs
  silent: true,
);

bool _shouldLoadPlaceholderUrl({
  required String placeholderUrl,
  required String imageUrl,
  required bool isLargeImage,
  required bool forceLoadPlaceholder,
}) {
  if (forceLoadPlaceholder) return true;

  final placeholder = placeholderUrl;

  // Small image
  if (!isLargeImage) return false;

  // Invalid placeholder URL
  if (placeholder.isEmpty) return false;

  // Same URL, no point in loading the placeholder
  if (placeholder == imageUrl) return false;

  return true;
}

bool _shouldForceFill(
  Size containerSize,
  double? imageWidth,
  double? imageHeight,
) {
  if (imageWidth == null || imageHeight == null) return false;

  if (containerSize.height < imageHeight) return true;
  if (containerSize.width < imageWidth) return true;

  return false;
}

bool _hasAspectRatioMismatch(
  double? placeholderAspectRatio,
  double? imageAspectRatio,
) {
  if (placeholderAspectRatio == null || imageAspectRatio == null) return false;

  return (placeholderAspectRatio - imageAspectRatio).abs() >
      _placeholderAspectRatioMismatchThreshold;
}

class ErrorPlaceholder extends StatelessWidget {
  const ErrorPlaceholder({
    super.key,
    this.borderRadius,
    this.onRetry,
  });

  final VoidCallback? onRetry;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) => ContentMediaOutcome(
    failed: true,
    child: KurumiImageErrorPlaceholder(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/error.png',
            color: Kurumi.themeOf(context).colorScheme.surface,
          ),
          if (onRetry case final retry?)
            Center(child: ImageRetryButton(onRetry: retry)),
        ],
      ),
    ),
  );
}

class _ContentMediaImageState extends StatefulWidget {
  const _ContentMediaImageState({
    required this.controller,
    required this.child,
  });
  final ExtendedImageController controller;
  final Widget child;
  @override
  State<_ContentMediaImageState> createState() =>
      _ContentMediaImageStateState();
}

class _ContentMediaImageStateState extends State<_ContentMediaImageState> {
  void _completed() {
    if (widget.controller.loadState.value == LoadState.completed) {
      reportContentMediaOutcome(context, failed: false);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.loadState.addListener(_completed);
    _completed();
  }

  @override
  void didUpdateWidget(_ContentMediaImageState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.loadState.removeListener(_completed);
    widget.controller.loadState.addListener(_completed);
    _completed();
  }

  @override
  void dispose() {
    widget.controller.loadState.removeListener(_completed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ImageRetryButton extends StatelessWidget {
  const ImageRetryButton({required this.onRetry, super.key});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onRetry,
    child: Text(context.t.generic.action.retry),
  );
}

class _ImageRetryControllerScope extends StatefulWidget {
  const _ImageRetryControllerScope({
    required this.builder,
    this.controller,
    this.beforeRetry,
  });
  final Widget Function(ExtendedImageController, VoidCallback) builder;
  final Future<void> Function()? beforeRetry;
  final ExtendedImageController? controller;

  @override
  State<_ImageRetryControllerScope> createState() =>
      _ImageRetryControllerScopeState();
}

class _ImageRetryControllerScopeState
    extends State<_ImageRetryControllerScope> {
  late final _owned = ExtendedImageController();
  var _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    _retrying = true;
    try {
      // Only the explicitly retried, failed request loses its disk payload.
      await widget.beforeRetry?.call();
    } catch (_) {
      // Cache availability must not prevent retrying the network request.
    } finally {
      _retrying = false;
    }
    if (mounted) (widget.controller ?? _owned).reload();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(widget.controller ?? _owned, _retry);

  @override
  void dispose() {
    _owned.dispose();
    super.dispose();
  }
}

class NullableAspectRatio extends StatelessWidget {
  const NullableAspectRatio({
    required this.child,
    super.key,
    this.aspectRatio,
  });

  final double? aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return aspectRatio == null
        ? child
        : AspectRatio(
            aspectRatio: aspectRatio!,
            child: child,
          );
  }
}
