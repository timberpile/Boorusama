import 'dart:async';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../../foundation/info/device_info.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/network/providers.dart';
import '../../../../developer_options/blocked_media_placeholder.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../../images/providers.dart';
import '../../../../images/booru_image.dart'
    show ErrorPlaceholder, ImageRetryButton;
import '../../../listing/types.dart';

/// A candidate never becomes the displayed source until its first frame decodes.
class ProgressivePostImage extends ConsumerWidget {
  const ProgressivePostImage({
    required this.mediaIdentity,
    required this.config,
    required this.imageUrl,
    required this.lowerMedia,
    required this.aspectRatio,
    required this.geometryAspectRatio,
    super.key,
    this.fit,
    this.imageCacheManager,
    this.controller,
    this.onRepresentationChanged,
  });

  final Object mediaIdentity;
  final BooruConfigAuth config;
  final String imageUrl;
  final GridThumbnailMedia lowerMedia;
  final double? aspectRatio;
  final double? geometryAspectRatio;
  final BoxFit? fit;
  final ImageCacheManager? imageCacheManager;
  final ExtendedImageController? controller;
  final ValueChanged<bool>? onRepresentationChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(automaticMediaLoadingEnabledProvider)) {
      return const BlockedMediaPlaceholder(borderRadius: BorderRadius.zero);
    }
    final dio = ref.watch(dioForWidgetProvider(config));
    final headers = ref.watch(httpHeadersProvider(config));
    final network = ref.watch(networkSettingsProvider(config));
    final overrideDio = network.activeMediaHostOverrides.isEmpty
        ? dio
        : ref.watch(mediaOverrideDioProvider(config));
    return RawProgressivePostImage(
      resolveRequest: (url) {
        final request = network.resolveMedia(url, headers: headers);
        return (
          url: request.url,
          dio: request.overridden ? overrideDio : dio,
          headers: request.headers,
        );
      },
      key: ValueKey((mediaIdentity, config)),
      dio: dio,
      headers: headers,
      imageUrl: imageUrl,
      lowerMedia: lowerMedia,
      aspectRatio: aspectRatio,
      geometryAspectRatio: geometryAspectRatio,
      fit: fit,
      cacheManager:
          imageCacheManager ?? ref.watch(defaultImageCacheManagerProvider),
      controller: controller,
      platform: Kurumi.themeOf(context).platform,
      androidVersion: ref
          .watch(deviceInfoProvider)
          .androidDeviceInfo
          ?.version
          .sdkInt,
      onRepresentationChanged: onRepresentationChanged,
    );
  }
}

class RawProgressivePostImage extends StatefulWidget {
  const RawProgressivePostImage({
    required this.dio,
    required this.imageUrl,
    required this.lowerMedia,
    required this.aspectRatio,
    required this.geometryAspectRatio,
    required this.cacheManager,
    super.key,
    this.headers = const {},
    this.resolveRequest,
    this.fit,
    this.controller,
    this.platform,
    this.androidVersion,
    this.onRepresentationChanged,
  });

  final ({String url, Dio dio, Map<String, String> headers}) Function(String)?
  resolveRequest;
  final Dio dio;
  final Map<String, String> headers;
  final String imageUrl;
  final GridThumbnailMedia lowerMedia;
  final double? aspectRatio;
  final double? geometryAspectRatio;
  final ImageCacheManager cacheManager;
  final BoxFit? fit;
  final ExtendedImageController? controller;
  final TargetPlatform? platform;
  final int? androidVersion;
  final ValueChanged<bool>? onRepresentationChanged;

  @override
  State<RawProgressivePostImage> createState() =>
      _RawProgressivePostImageState();
}

class _RawProgressivePostImageState extends State<RawProgressivePostImage> {
  late final _controller = widget.controller ?? ExtendedImageController();
  final _requests = <_DecodedCandidate>[];
  ImageProvider? _displayed;
  double? _displayedRatio;
  var _targetGeneration = 0;
  var _targetSucceeded = false;
  var _targetFailed = false;
  var _lowerFailed = false;
  var _initialized = false;
  var _retrying = false;
  final _failedUrls = <String>{};
  _DecodedCandidate? _target;

  // An unresolved listing can still call its small thumbnail the original.
  // Keep it as a final fallback instead of letting it replace the grid image.
  bool get _targetIsFallback =>
      widget.lowerMedia.url.isNotEmpty &&
      widget.lowerMedia.url != widget.imageUrl &&
      (widget.lowerMedia.fallbackUrl == widget.imageUrl ||
          widget.lowerMedia.placeholderUrl == widget.imageUrl);

  List<String> _lowerCandidates() =>
      [
            widget.lowerMedia.url,
            ...widget.lowerMedia.fallbackUrls,
            widget.lowerMedia.fallbackUrl,
            widget.lowerMedia.placeholderUrl,
          ].nonNulls
          .where(
            (url) =>
                url.isNotEmpty && (url != widget.imageUrl || _targetIsFallback),
          )
          .toSet()
          .toList();

  @override
  void initState() {
    super.initState();
    _controller.clearImage();
    _controller.changeLoadState(LoadState.loading);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final candidates = _lowerCandidates();
    if (candidates.isNotEmpty) {
      _loadLower(candidates);
    } else {
      _lowerFailed = true;
    }
    _loadTarget();
  }

  @override
  void didUpdateWidget(covariant RawProgressivePostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _loadTarget();
    if (_displayed != null &&
        _compatible(_displayedRatio, oldWidget.geometryAspectRatio) !=
            _compatible(_displayedRatio, widget.geometryAspectRatio)) {
      // Metadata recovery can change edge readiness without a new provider or
      // frame. Publish only the effective transition, preserving retained pixels.
      widget.onRepresentationChanged?.call(
        _compatible(_displayedRatio, widget.geometryAspectRatio),
      );
    }
  }

  void _loadLower(List<String> candidates, [int start = 0]) {
    final index = candidates.indexWhere(
      (url) => url != widget.imageUrl || _targetIsFallback,
      start,
    );
    if (index < 0) {
      setState(() => _lowerFailed = true);
      return;
    }
    _stage(
      candidates[index],
      onDecoded: (provider, decodedRatio) {
        if (_targetSucceeded || _displayed != null) return false;
        _show(provider, decodedRatio);
        return true;
      },
      onError: () {
        if (_targetSucceeded) return;
        if (index + 1 < candidates.length) {
          _loadLower(candidates, index + 1);
        } else {
          setState(() => _lowerFailed = true);
        }
      },
    );
  }

  void _loadTarget() {
    _target?.dispose();
    final generation = ++_targetGeneration;
    _targetSucceeded = false;
    _targetFailed = false;
    if (_targetIsFallback) return;
    if (widget.imageUrl.isEmpty) {
      _targetFailed = true;
      return;
    }
    _target = _stage(
      widget.imageUrl,
      onDecoded: (provider, ratio) {
        if (generation != _targetGeneration) return false;
        _targetSucceeded = true;
        _show(provider, ratio);
        return true;
      },
      onError: () {
        if (generation != _targetGeneration) return;
        setState(() => _targetFailed = true);
      },
    );
  }

  _DecodedCandidate _stage(
    String url, {
    required bool Function(ImageProvider provider, double ratio) onDecoded,
    required VoidCallback onError,
  }) {
    final token = CancelToken();
    // This factory preserves the application's PNG/AVIF, media-purpose marker,
    // configured transport, cache and retry paths. The same provider is displayed.
    final request =
        widget.resolveRequest?.call(url) ??
        (url: url, dio: widget.dio, headers: widget.headers);
    final provider = ExtendedImage.network(
      request.url,
      dio: request.dio,
      headers: request.headers,
      cancelToken: token,
      platform: widget.platform,
      androidVersion: widget.androidVersion,
      cacheManager: widget.cacheManager,
      fetchStrategy: _fetchStrategy,
    ).image;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final candidate = _DecodedCandidate(stream, token);
    _requests.add(candidate);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronous) {
        if (!mounted || candidate.disposed) {
          info.dispose();
          candidate.removeListener();
          return;
        }
        if (candidate.decoded) {
          info.dispose();
          return;
        }
        candidate.decoded = true;
        final ratio = info.image.width / info.image.height;
        candidate.holdDecodedStream();
        final displayed = onDecoded(provider, ratio);
        info.dispose();
        if (!displayed) {
          candidate.removeListener();
          candidate.releaseHandle();
          return;
        }
        // Without decoded-cache admission, a keepAlive handle prevents disposal
        // but removing the last listener also removes the cache's live-key
        // lookup. Keep this listener until ExtendedImage attaches in the frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          candidate.removeListener();
          candidate.releaseHandle();
        });
      },
      onError: (error, stack) {
        candidate.removeListener();
        // Failed staged providers never attach to ExtendedImage's error
        // handler. Evict this terminal candidate's decoded-cache key so its
        // pending listener is released. Its private CancelToken separates it
        // from replacement candidates; this does not remove disk payloads.
        unawaited(provider.evict());
        if (!mounted || candidate.disposed) return;
        _failedUrls.add(url);
        onError();
      },
    );
    candidate.listener = listener;
    stream.addListener(listener);
    return candidate;
  }

  void _show(ImageProvider provider, double ratio) {
    setState(() {
      _displayed = provider;
      _displayedRatio = ratio;
    });
    // A completed-to-completed replacement must invalidate a held edge drag,
    // while subsequent animated frames do not constitute a representation change.
    widget.onRepresentationChanged?.call(
      _compatible(ratio, widget.geometryAspectRatio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;
    if (displayed == null) {
      return (_targetFailed || _targetIsFallback) && _lowerFailed
          ? ErrorPlaceholder(
              borderRadius: BorderRadius.zero,
              onRetry: _retryFailed,
            )
          : const KurumiImagePlaceholder(borderRadius: BorderRadius.zero);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ExtendedImage(
            image: displayed,
            controller: _controller,
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null,
            borderRadius: BorderRadius.zero,
            gaplessPlayback: true,
            // Cropped previews belong at the top of tall content: AutoComic already
            // positions that content at its top before a full representation decodes.
            alignment:
                _compatible(_displayedRatio, widget.aspectRatio) ||
                    (widget.aspectRatio ?? 1) >= 1
                ? Alignment.center
                : Alignment.topCenter,
            fit: _compatible(_displayedRatio, widget.aspectRatio)
                ? widget.fit ?? BoxFit.contain
                : BoxFit.contain,
            placeholderWidget: const KurumiImagePlaceholder(
              borderRadius: BorderRadius.zero,
            ),
            errorWidget: ErrorPlaceholder(
              borderRadius: BorderRadius.zero,
              onRetry: _retryFailed,
            ),
          ),
        ),
        if (_targetFailed)
          Align(
            alignment: Alignment.bottomCenter,
            child: ImageRetryButton(onRetry: _retrying ? null : _retryFailed),
          ),
      ],
    );
  }

  Future<void> _retryFailed() async {
    if (_retrying) return;
    final generation = _targetGeneration;
    setState(() => _retrying = true);
    try {
      for (final url in _failedUrls.toList()) {
        final requestUrl = widget.resolveRequest?.call(url).url ?? url;
        try {
          await widget.cacheManager.clearCache(
            widget.cacheManager.generateCacheKey(requestUrl),
          );
        } catch (_) {
          // Cache I/O is optional. Retrying never removes the decoded preview.
        }
      }
      if (!mounted || generation != _targetGeneration) return;
      _failedUrls.clear();
      setState(() {
        if (_targetFailed) _loadTarget();
        if (_lowerFailed && _displayed == null) {
          _lowerFailed = false;
          _loadLower(_lowerCandidates());
        }
      });
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  void dispose() {
    for (final candidate in _requests) {
      candidate.dispose();
    }
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }
}

bool _compatible(double? actual, double? expected) =>
    actual != null && expected != null && (actual - expected).abs() <= 0.05;
const _fetchStrategy = FetchStrategyBuilder(
  initialPauseBetweenRetries: Duration(milliseconds: 500),
  silent: true,
);

class _DecodedCandidate {
  _DecodedCandidate(this.stream, this.token);
  final ImageStream stream;
  final CancelToken token;
  ImageStreamListener? listener;
  ImageStreamCompleterHandle? handle;
  var disposed = false;
  var decoded = false;
  void holdDecodedStream() => handle ??= stream.completer?.keepAlive();
  void removeListener() {
    final current = listener;
    if (current != null) stream.removeListener(current);
    listener = null;
  }

  void releaseHandle() {
    handle?.dispose();
    handle = null;
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    if (decoded) removeListener();
    releaseHandle();
    // Keep the error listener until cancellation settles. Removing it first
    // makes the decoder's cancelled Future an unhandled image-cache error.
    token.cancel('Image candidate superseded.');
  }
}
