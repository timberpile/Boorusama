import 'dart:async';

import 'package:cache_manager/cache_manager.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../../../foundation/info/device_info.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/network/providers.dart';
import '../../../../content/content_media_access.dart';
import '../../../../content/content_media_dio.dart';
import '../../../../content/content_media_failures.dart';
import '../../../../developer_options/blocked_media_placeholder.dart';
import '../../../../developer_options/providers.dart';
import '../../../../http/client/providers.dart';
import '../../../../images/providers.dart';
import '../../../../images/booru_image.dart'
    show ErrorPlaceholder, ImageRetryButton;
import '../../../listing/types.dart';
import '../../../post/types.dart';
import '../types/post_presentation_fallback_reason.dart';

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
    this.post,
    this.imageCacheManager,
    this.controller,
    this.onRepresentationChanged,
    this.onTerminalFailure,
    this.onImageSize,
    this.intermediateImageUrls = const [],
  });

  final Post? post;
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
  final VoidCallback? onTerminalFailure;
  final ValueChanged<Size>? onImageSize;
  final List<String> intermediateImageUrls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(automaticMediaLoadingEnabledProvider)) {
      return const BlockedMediaPlaceholder(borderRadius: BorderRadius.zero);
    }
    final access = watchContentMediaAccess(ref, config, post: post);
    final publicSource = config.anonymousReadScope?.source;
    bool permitted(String? value) {
      if (value == null || value.isEmpty) return false;
      if (publicSource == null) return true;
      final uri = Uri.tryParse(value);
      return uri != null && publicSource.allowsMedia(uri);
    }

    if (!access.allowed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onTerminalFailure?.call(),
      );
      return const KurumiImagePlaceholder(borderRadius: BorderRadius.zero);
    }
    final safeLower = publicSource == null
        ? lowerMedia
        : GridThumbnailMedia(
            url: permitted(lowerMedia.url) ? lowerMedia.url : '',
            aspectRatio: lowerMedia.aspectRatio,
            placeholderUrl: permitted(lowerMedia.placeholderUrl)
                ? lowerMedia.placeholderUrl
                : null,
            fallbackUrl: permitted(lowerMedia.fallbackUrl)
                ? lowerMedia.fallbackUrl
                : null,
            fallbackUrls: lowerMedia.fallbackUrls.where(permitted).toList(),
            probeImageFormats: lowerMedia.probeImageFormats,
            placeholderAspectRatio: lowerMedia.placeholderAspectRatio,
            placeholderFit: lowerMedia.placeholderFit,
          );
    final safeIntermediate = intermediateImageUrls.where(permitted).toList();
    final safeCandidates = <String>{
      safeLower.url,
      ...safeLower.fallbackUrls,
      if (safeLower.fallbackUrl case final value?) value,
      if (safeLower.placeholderUrl case final value?) value,
      ...safeIntermediate,
    }.where((url) => url.isNotEmpty).toList();
    final safeImageUrl = permitted(imageUrl)
        ? imageUrl
        : safeCandidates.firstOrNull;
    if (safeImageUrl == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onTerminalFailure?.call(),
      );
      return const ErrorPlaceholder(
        borderRadius: BorderRadius.zero,
        reason: PostPresentationFallbackReason.unavailableEngine,
      );
    }
    final effectiveLower = permitted(imageUrl)
        ? safeLower
        : GridThumbnailMedia(
            url: safeCandidates.first,
            aspectRatio: safeLower.aspectRatio,
            fallbackUrls: safeCandidates.skip(1).toList(),
            probeImageFormats: safeLower.probeImageFormats,
            placeholderAspectRatio: safeLower.placeholderAspectRatio,
            placeholderFit: safeLower.placeholderFit,
          );
    final effectiveIntermediate = safeIntermediate
        .where((url) => url != safeImageUrl)
        .toList();

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
    final dio = access.key == null
        ? ref.watch(dioForWidgetProvider(config))
        : ref.watch(contentMediaDioProvider(access.key!));
    final headers = ref.watch(httpHeadersProvider(config));
    final network = ref.watch(networkSettingsProvider(config));
    final requests = [
      safeImageUrl,
      effectiveLower.url,
      ...effectiveLower.fallbackUrls,
      ?effectiveLower.fallbackUrl,
      ?effectiveLower.placeholderUrl,
      ...effectiveIntermediate,
    ];
    final needsOverride = requests
        .where((url) => url.isNotEmpty)
        .any(
          (url) => network
              .resolveMedia(url, headers: headers, sourceUrl: config.url)
              .overridden,
        );
    final overrideDio = needsOverride && access.key == null
        ? ref.watch(mediaOverrideDioProvider(config))
        : dio;
    return RawProgressivePostImage(
      resolveRequest: (url) {
        final request = network.resolveMedia(
          url,
          headers: headers,
          sourceUrl: config.url,
        );
        return (
          url: request.url,
          dio: request.overridden ? overrideDio : dio,
          headers: request.headers,
        );
      },
      key: ValueKey((mediaIdentity, config, access.key)),
      dio: dio,
      headers: headers,
      imageUrl: safeImageUrl,
      lowerMedia: effectiveLower,
      aspectRatio: aspectRatio,
      geometryAspectRatio: geometryAspectRatio,
      fit: fit,
      cacheManager: manager,
      controller: controller,
      platform: Kurumi.themeOf(context).platform,
      androidVersion: ref
          .watch(deviceInfoProvider)
          .androidDeviceInfo
          ?.version
          .sdkInt,
      onRepresentationChanged: onRepresentationChanged,
      onTerminalFailure: onTerminalFailure,
      onImageSize: onImageSize,
      intermediateImageUrls: effectiveIntermediate,
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
    this.onTerminalFailure,
    this.onImageSize,
    this.intermediateImageUrls = const [],
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
  final VoidCallback? onTerminalFailure;
  final ValueChanged<Size>? onImageSize;
  final List<String> intermediateImageUrls;

  @override
  State<RawProgressivePostImage> createState() =>
      _RawProgressivePostImageState();
}

class _RawProgressivePostImageState extends State<RawProgressivePostImage> {
  late final _controller = widget.controller ?? ExtendedImageController();
  final _requests = <_DecodedCandidate>[];
  final _intermediateRequests = <_DecodedCandidate>[];
  ImageProvider? _displayed;
  String? _displayedUrl;
  var _displayedLevel = -1;
  double? _displayedRatio;
  var _targetGeneration = 0;
  var _targetSucceeded = false;
  var _targetFailed = false;
  var _lowerFailed = false;
  var _reportedTerminalFailure = false;
  var _initialized = false;
  var _retrying = false;
  final _failedUrls = <String>{};
  _DecodedCandidate? _target;

  List<String> get _intermediateUrls => _targetIsFallback
      ? const []
      : widget.intermediateImageUrls
            .where(
              (url) =>
                  url.isNotEmpty &&
                  url != widget.imageUrl &&
                  url != widget.lowerMedia.url,
            )
            .toSet()
            .toList();

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
          .where((url) => !_intermediateUrls.contains(url))
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
    if (oldWidget.imageUrl != widget.imageUrl ||
        !listEquals(
          oldWidget.intermediateImageUrls,
          widget.intermediateImageUrls,
        )) {
      _loadTarget();
    }
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

  void _reportTerminalFailure() {
    if (_reportedTerminalFailure ||
        _displayed != null ||
        !_lowerFailed ||
        !(_targetFailed || _targetIsFallback) ||
        _intermediateRequests.any(
          (request) => !request.decoded && !request.failed && !request.disposed,
        )) {
      return;
    }
    _reportedTerminalFailure = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _displayed == null &&
          _lowerFailed &&
          (_targetFailed || _targetIsFallback)) {
        widget.onTerminalFailure?.call();
      }
    });
  }

  void _loadLower(List<String> candidates, [int start = 0]) {
    final index = candidates.indexWhere(
      (url) => url != widget.imageUrl || _targetIsFallback,
      start,
    );
    if (index < 0) {
      setState(() => _lowerFailed = true);
      _reportTerminalFailure();
      return;
    }
    _stage(
      candidates[index],
      onDecoded: (provider, size) {
        final decodedRatio = size.width / size.height;
        if (_targetSucceeded || _displayed != null) return false;
        _show(provider, decodedRatio, candidates[index], 0);
        return true;
      },
      onError: () {
        if (_targetSucceeded) return;
        if (index + 1 < candidates.length) {
          _loadLower(candidates, index + 1);
        } else {
          setState(() => _lowerFailed = true);
          _reportTerminalFailure();
        }
      },
    );
  }

  void _loadTarget() {
    _target?.dispose();
    for (final request in _intermediateRequests) {
      request.dispose();
    }
    _intermediateRequests.clear();
    final generation = ++_targetGeneration;
    _targetSucceeded = false;
    _targetFailed = false;
    _reportedTerminalFailure = false;
    if (_targetIsFallback) {
      _reportTerminalFailure();
      return;
    }
    if (widget.imageUrl.isEmpty) {
      _targetFailed = true;
      _reportTerminalFailure();
      return;
    }
    final intermediates = _intermediateUrls;
    final displayedIndex = intermediates.indexOf(_displayedUrl ?? '');
    _displayedLevel = _displayed == null
        ? -1
        : _displayedUrl == widget.lowerMedia.url
        ? 0
        : displayedIndex >= 0
        ? displayedIndex + 1
        : intermediates.length + 1;
    for (final (index, url) in intermediates.indexed) {
      if (url == _displayedUrl) continue;
      final level = index + 1;
      _intermediateRequests.add(
        _stage(
          url,
          onDecoded: (provider, size) {
            final ratio = size.width / size.height;
            if (generation != _targetGeneration ||
                _targetSucceeded ||
                level <= _displayedLevel)
              return false;
            widget.onImageSize?.call(size);
            _show(provider, ratio, url, level);
            return true;
          },
          onError: _reportTerminalFailure,
        ),
      );
    }
    _target = _stage(
      widget.imageUrl,
      onDecoded: (provider, size) {
        final ratio = size.width / size.height;
        if (generation != _targetGeneration) return false;
        _targetSucceeded = true;
        widget.onImageSize?.call(size);
        _show(provider, ratio, widget.imageUrl, intermediates.length + 1);
        return true;
      },
      onError: () {
        if (generation != _targetGeneration) return;
        setState(() => _targetFailed = true);
        _reportTerminalFailure();
      },
    );
  }

  _DecodedCandidate _stage(
    String url, {
    required bool Function(ImageProvider provider, Size size) onDecoded,
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
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        candidate.holdDecodedStream();
        final displayed = onDecoded(provider, size);
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
        candidate.failed = true;
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

  void _show(ImageProvider provider, double ratio, String url, int level) {
    _reportedTerminalFailure = false;
    setState(() {
      _displayed = provider;
      _displayedRatio = ratio;
      _displayedUrl = url;
      _displayedLevel = level;
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
    return ContentMediaOutcome(
      failed: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => ExtendedImage(
              image: displayed,
              controller: _controller,
              width: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : null,
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
              alignment: Alignment.topCenter,
              // Unknown geometry fills the viewer: its bottom edge lies behind
              // the action footer. Keep retry below the standard top controls.
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: kToolbarHeight + 8),
                  child: ImageRetryButton(
                    onRetry: _retrying ? null : _retryFailed,
                  ),
                ),
              ),
            ),
        ],
      ),
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
      _reportedTerminalFailure = false;
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
  var failed = false;
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
