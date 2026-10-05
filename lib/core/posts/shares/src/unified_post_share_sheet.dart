// ignore_for_file: avoid_catching_errors
import 'dart:typed_data';
import 'dart:async';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../foundation/clipboard.dart';
import '../../../../foundation/filesystem.dart';
import '../../../config_widgets/website_logo.dart';
import '../../../../foundation/platform.dart';
import '../../../configs/config/types.dart';
import '../../../ddos/handler/providers.dart';
import '../../../http/client/providers.dart';
import '../../../downloads/urls/providers.dart';
import '../../../http/client/types.dart';
import '../../details/providers.dart';
import '../../post/providers.dart';
import '../../post/types.dart';
import '../../sources/types.dart';
import 'share_cached_image_description.dart';
import 'share_action_adapter.dart';
import 'share_media_description.dart';
import 'share_platform_capabilities.dart';
import 'share_resolution_control.dart';
import 'share_media_url_resolution.dart';
import 'share_media_preparation.dart';
import 'share_payload_tile.dart';
import 'share_payloads.dart';

enum _ShareSegment { media, links }

class UnifiedPostShareSheet extends ConsumerStatefulWidget {
  const UnifiedPostShareSheet({
    required this.post,
    required this.auth,
    required this.viewer,
    required this.imageCacheManager,
    this.shareAdapter,
    this.imageClipboardWriter,
    this.profileIconUrl,
    this.imageFileClipboardWriter,
    super.key,
  });

  final Post post;
  final BooruConfigAuth auth;
  final BooruConfigViewer viewer;
  final ImageCacheManager imageCacheManager;
  final ShareActionAdapter? shareAdapter;
  final Future<void> Function(Uint8List)? imageClipboardWriter;
  final Future<void> Function(String path, String mimeType)?
  imageFileClipboardWriter;
  final String? profileIconUrl;

  @override
  ConsumerState<UnifiedPostShareSheet> createState() =>
      _UnifiedPostShareSheetState();
}

class _UnifiedPostShareSheetState extends ConsumerState<UnifiedPostShareSheet>
    with WidgetsBindingObserver {
  _ShareSegment _segment = _ShareSegment.media;
  CancelToken? _cancelToken;
  SharePayload? _active;
  double? _progress;
  Timer? _progressVisibilityTimer;
  var _showProgress = false;
  var _clipboardHandoff = false;
  String? _error;
  (SharePayload, bool)? _retry;
  var _nativeMediaShareUnsupported = false;
  String? _imageMetadataUrl;
  ImageCacheManager? _imageMetadataCacheManager;
  BooruConfigAuth? _imageMetadataAuth;
  Post? _imageMetadataPost;
  String? _cachedImageDescription;
  var _imageMetadataRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _progressVisibilityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cancelActiveMedia();
    }
  }

  void _cancelActiveMedia() {
    if (_clipboardHandoff) return;
    _progressVisibilityTimer?.cancel();
    _progressVisibilityTimer = null;
    _cancelToken?.cancel();
    if (mounted && _showProgress) {
      setState(() => _showProgress = false);
    }
  }

  void _beginImageMetadataLookup(String imageUrl) {
    if (_imageMetadataUrl == imageUrl &&
        identical(_imageMetadataCacheManager, widget.imageCacheManager) &&
        identical(_imageMetadataAuth, widget.auth) &&
        identical(_imageMetadataPost, widget.post)) {
      return;
    }

    _imageMetadataUrl = imageUrl;
    _imageMetadataCacheManager = widget.imageCacheManager;
    _imageMetadataAuth = widget.auth;
    _imageMetadataPost = widget.post;
    _cachedImageDescription = null;
    final revision = ++_imageMetadataRevision;
    if (!widget.post.isVideo && imageUrl.isNotEmpty) {
      unawaited(
        _loadCachedImageDescription(
          imageUrl,
          widget.imageCacheManager,
          revision,
        ),
      );
    }
  }

  Future<void> _loadCachedImageDescription(
    String imageUrl,
    ImageCacheManager cacheManager,
    int revision,
  ) async {
    String? description;
    try {
      final cacheKey = cacheManager.generateCacheKey(imageUrl);
      final bytes = await cacheManager.getCachedFileBytes(cacheKey);
      description = await cachedShareImageDescription(bytes);
    } catch (_) {
      return;
    }

    if (mounted && revision == _imageMetadataRevision && description != null) {
      setState(() => _cachedImageDescription = description);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final imageUrl = ref
        .watch(mediaUrlResolverProvider(widget.auth))
        .resolveMediaUrl(post, widget.viewer);
    _beginImageMetadataLookup(imageUrl);
    final booruLink = ref
        .watch(postLinkGeneratorProvider(widget.auth))
        .getLink(post);
    final sourceLink = switch (post.source) {
      final WebSource source => source.uri.toString(),
      _ => null,
    };
    final extractor = ref.watch(downloadFileUrlExtractorProvider(widget.auth));
    final payloads = PostSharePayloads.build(
      isVideo: post.isVideo,
      canResolveExactOriginal: hasExactOriginalSource(post, extractor),
      canResolveExactVideo: hasExactVideoSource(post, extractor),
      viewerImageUrl: imageUrl,
      originalUrl: post.isVideo ? post.videoUrl : post.originalImageUrl,
      booruLink: booruLink,
      sourceLink: sourceLink,
      postId: post.id,
    );
    final capabilities = SharePlatformCapabilities.forPlatform(
      currentAppPlatform(),
    );
    final canShareMedia =
        capabilities.canShareMedia && !_nativeMediaShareUnsupported;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t.post.action.share,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    KurumiSegmentedButton<_ShareSegment>(
                      initialValue: _segment,
                      segments: {
                        _ShareSegment.media: context.t.post.action.media,
                        _ShareSegment.links: context.t.post.action.links,
                      },
                      onChanged: (value) => setState(() => _segment = value),
                    ),
                    const SizedBox(height: 12),
                    if (_segment == _ShareSegment.media && !canShareMedia)
                      Text(context.t.post.action.media_platform_unavailable),
                    if (_segment == _ShareSegment.media &&
                        !post.isVideo &&
                        !capabilities.canCopyImage)
                      Text(
                        context.t.post.action.image_copy_platform_unavailable,
                      ),
                    for (final payload in switch (_segment) {
                      _ShareSegment.media => payloads.media,
                      _ShareSegment.links => payloads.links,
                    }) ...[
                      SharePayloadTile(
                        key: ValueKey(payload.id),
                        leading: _leadingIcon(payload.id, sourceLink),
                        title: _title(context, payload.id),
                        value: payload.value,
                        deferred: payload.deferred,
                        showValue: !payload.isMedia,
                        reserveDescriptionSpace:
                            payload.id == SharePayloadId.image,
                        description:
                            payload.id == SharePayloadId.image &&
                                _cachedImageDescription != null
                            ? _cachedImageDescription
                            : shareMediaDescription(
                                post: post,
                                payload: payload,
                                viewerImageUrl: imageUrl,
                              ),
                        unavailable: context.t.post.action.unavailable,
                        copyTooltip: _copyTooltip(context, payload.id),
                        shareTooltip: _shareTooltip(context, payload.id),
                        onCopy:
                            payload.canCopy &&
                                (payload.id == SharePayloadId.video ||
                                    !payload.isMedia ||
                                    capabilities.canCopyImage)
                            ? () => _perform(payload, share: false)
                            : null,
                        onShare:
                            payload.canShare &&
                                (!payload.isMedia || canShareMedia)
                            ? () => _perform(payload, share: true)
                            : null,
                        busy: _active != null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              if ((_cancelToken != null && _showProgress) || _error != null)
                Positioned(
                  left: 0,
                  right: _error == null ? 0 : 112,
                  bottom: 0,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_cancelToken != null && _showProgress) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _clipboardHandoff
                                        ? context
                                              .t
                                              .post
                                              .action
                                              .copying_to_clipboard
                                        : context.t.post.action.preparing_media,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!_clipboardHandoff)
                                  TextButton(
                                    onPressed: _cancelActiveMedia,
                                    child: Text(context.t.post.action.cancel),
                                  ),
                              ],
                            ),
                            _progress == null || _progress! < 0
                                ? const LinearProgressIndicator()
                                : LinearProgressIndicator(value: _progress),
                          ],
                          if (_error case final error?) ...[
                            Text(
                              error,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            if (_retry != null)
                              TextButton(
                                onPressed: () {
                                  final attempt = _retry!;
                                  _perform(attempt.$1, share: attempt.$2);
                                },
                                child: Text(context.t.post.action.retry),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(SharePayloadId id, String? sourceLink) => switch (id) {
    SharePayloadId.image => const Icon(Icons.image_outlined),
    SharePayloadId.original => const Icon(Icons.photo_outlined),
    SharePayloadId.video => const Icon(Icons.movie_outlined),
    SharePayloadId.booruLink => ConfigAwareWebsiteLogo.fromConfig(
      widget.auth,
      width: 24,
      height: 24,
      customIconUrl: widget.profileIconUrl,
    ),
    SharePayloadId.sourceLink => ConfigAwareWebsiteLogo(
      url: sourceLink,
      size: 24,
    ),
    SharePayloadId.imageLink => const Icon(Icons.link),
    SharePayloadId.postId => const Icon(Icons.tag),
  };

  Future<void> _perform(
    SharePayload payload, {
    required bool share,
  }) async {
    if (_active != null || !payload.available) return;
    final token = payload.isMedia ? CancelToken() : null;
    _progressVisibilityTimer?.cancel();
    setState(() {
      _error = null;
      _retry = null;
      _active = payload;
      _progress = null;
      _showProgress = false;
      _cancelToken = token;
    });
    if (token != null) {
      _progressVisibilityTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && identical(_cancelToken, token) && !token.isCancelled) {
          setState(() => _showProgress = true);
        }
      });
    }

    ShareMediaLease? lease;
    try {
      final value = payload.value;
      if (payload.id == SharePayloadId.video && !share) {
        final request = await resolveShareMediaUrl(
          payload: payload,
          post: widget.post,
          extractor: ref.read(downloadFileUrlExtractorProvider(widget.auth)),
          cancelToken: token,
        );
        checkShareCancellation(token);
        if (!mounted) return;
        _beginClipboardHandoff();
        await AppClipboard.copy(request.url);
      } else if (payload.isMedia) {
        final fs = ref.read(appFileSystemProvider);
        String? rootPath;
        try {
          rootPath = await awaitShareOrCancellation(
            fs.getTemporaryPath(),
            token,
          );
        } on ShareMediaException {
          rethrow;
        } on Exception {
          throw const ShareMediaException(ShareMediaFailure.storage);
        }
        checkShareCancellation(token);
        if (!mounted) return;
        if (rootPath == null) {
          throw const ShareMediaException(ShareMediaFailure.storage);
        }
        final request = await resolveShareMediaUrl(
          payload: payload,
          post: widget.post,
          extractor: ref.read(downloadFileUrlExtractorProvider(widget.auth)),
          cancelToken: token,
        );
        checkShareCancellation(token);
        if (!mounted) return;
        Map<String, String> bypassHeaders;
        try {
          bypassHeaders = await awaitShareOrCancellation(
            ref.read(bypassDdosHeadersProvider(request.url).future),
            token,
          );
        } on ShareMediaException {
          rethrow;
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) {
            throw const ShareMediaException(ShareMediaFailure.cancelled);
          }
          if (error.response?.statusCode == 401 ||
              error.response?.statusCode == 403) {
            throw const ShareMediaException(ShareMediaFailure.authentication);
          }
          throw const ShareMediaException(ShareMediaFailure.network);
        } on Exception {
          throw const ShareMediaException(ShareMediaFailure.network);
        }
        checkShareCancellation(token);
        if (!mounted) return;
        final requestHeaders = {
          ...ref.read(httpHeadersProvider(widget.auth)),
          ...bypassHeaders,
          if (request.cookie != null)
            AppHttpHeaders.cookieHeader: request.cookie!,
        };
        final service = ShareMediaPreparation(
          rootPath: rootPath,
          dio: ref.read(dioForWidgetProvider(widget.auth)),
          cachedBytes: (url) async =>
              widget.imageCacheManager.getCachedFileBytes(
                widget.imageCacheManager.generateCacheKey(url),
              ),
          imageCacheManager: widget.imageCacheManager,
        );
        lease = await service.prepare(
          url: request.url,
          kind: switch (payload.id) {
            SharePayloadId.video => ShareMediaKind.video,
            SharePayloadId.original => ShareMediaKind.original,
            _ => ShareMediaKind.image,
          },
          fallbackExtension: widget.post.format,
          headers: requestHeaders,
          cancelToken: token,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        );
        checkShareCancellation(token);
        if (!mounted) return;
        if (share) {
          _progressVisibilityTimer?.cancel();
          _progressVisibilityTimer = null;
          _cancelToken = null;
          setState(() => _showProgress = false);
          final ShareActionOutcome outcome;
          if (isAndroid() &&
              payload.id != SharePayloadId.video &&
              widget.shareAdapter == null) {
            await AppClipboard.shareImageFile(lease.path, lease.mimeType);
            outcome = ShareActionOutcome.success;
          } else {
            outcome =
                await (widget.shareAdapter ??
                        ShareActionAdapter(SharePlus.instance.share))
                    .shareMedia(lease.path, lease.mimeType);
          }
          _handleShareOutcome(payload, share, outcome);
        } else {
          setState(() => _progress = null);
          if (widget.imageFileClipboardWriter != null ||
              widget.imageClipboardWriter == null) {
            _beginClipboardHandoff();
            await (widget.imageFileClipboardWriter ??
                AppClipboard.copyImageFile)(
              lease.path,
              lease.mimeType,
            );
          } else {
            Uint8List bytes;
            try {
              bytes = await awaitShareOrCancellation(
                fs.readBytes(lease.path),
                token,
              );
            } on ShareMediaException {
              rethrow;
            } on Exception {
              throw const ShareMediaException(ShareMediaFailure.storage);
            }
            checkShareCancellation(token);
            _beginClipboardHandoff();
            await (widget.imageClipboardWriter ?? AppClipboard.copyImageBytes)(
              bytes,
            );
          }
        }
      } else if (share) {
        final adapter =
            widget.shareAdapter ?? ShareActionAdapter(SharePlus.instance.share);
        final outcome = payload.id == SharePayloadId.postId
            ? await adapter.shareText(value!)
            : await adapter.shareLink(Uri.parse(value!));
        _handleShareOutcome(payload, share, outcome);
      } else {
        await AppClipboard.copy(value!);
      }
      if (mounted && !share) {
        showToast(
          context.t.post.action.copied,
          position: ToastPosition.bottom,
        );
      }
    } on ShareMediaException catch (error) {
      if (mounted &&
          error.failure != ShareMediaFailure.cancelled &&
          token?.isCancelled != true) {
        _showFailure(
          payload,
          share,
          _mediaError(context, error.failure),
        );
      }
    } on UnimplementedError {
      if (mounted && token?.isCancelled != true) {
        _showFailure(
          payload,
          share,
          payload.isMedia && payload.id != SharePayloadId.video
              ? context.t.post.action.image_copy_platform_unavailable
              : context.t.post.action.clipboard_unavailable,
        );
      }
    } on Exception {
      if (mounted && token?.isCancelled != true) {
        _showFailure(
          payload,
          share,
          share
              ? context.t.post.action.share_target_unavailable
              : context.t.post.action.clipboard_unavailable,
        );
      }
    } finally {
      _progressVisibilityTimer?.cancel();
      _progressVisibilityTimer = null;
      _cancelToken = null;
      _clipboardHandoff = false;
      if (lease != null) await lease.release();
      if (mounted) {
        setState(() {
          _active = null;
          _progress = null;
          _showProgress = false;
        });
      }
    }
  }

  void _beginClipboardHandoff() {
    if (mounted) {
      setState(() {
        _clipboardHandoff = true;
        _progress = null;
      });
    }
  }

  void _handleShareOutcome(
    SharePayload payload,
    bool share,
    ShareActionOutcome outcome,
  ) {
    if (!mounted) return;
    switch (outcome) {
      case ShareActionOutcome.success || ShareActionOutcome.dismissed:
        break;
      case ShareActionOutcome.unavailable:
        _showFailure(
          payload,
          share,
          context.t.post.action.share_result_unavailable,
        );
      case ShareActionOutcome.unsupported:
        if (payload.isMedia) {
          setState(() => _nativeMediaShareUnsupported = true);
        }
        _showFailure(
          payload,
          share,
          payload.isMedia
              ? context.t.post.action.media_platform_unavailable
              : context.t.post.action.share_platform_unavailable,
          retryable: false,
        );
    }
  }

  void _showFailure(
    SharePayload payload,
    bool share,
    String message, {
    bool retryable = true,
  }) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _retry = retryable ? (payload, share) : null;
    });
  }
}

String _title(BuildContext context, SharePayloadId id) => switch (id) {
  SharePayloadId.image => context.t.post.action.image,
  SharePayloadId.original => context.t.post.action.original,
  SharePayloadId.video => context.t.post.action.video,
  SharePayloadId.booruLink => context.t.post.action.booru_link,
  SharePayloadId.sourceLink => context.t.post.action.source_link,
  SharePayloadId.imageLink => context.t.post.action.image_link,
  SharePayloadId.postId => context.t.post.action.post_id,
};

String _copyTooltip(BuildContext context, SharePayloadId id) => switch (id) {
  SharePayloadId.image => context.t.post.action.copy_image,
  SharePayloadId.original => context.t.post.action.copy_original,
  SharePayloadId.video => context.t.post.action.copy_video_link,
  SharePayloadId.booruLink => context.t.post.action.copy_post_link,
  SharePayloadId.sourceLink => context.t.post.action.copy_source_link,
  SharePayloadId.imageLink => context.t.post.action.copy_image_link,
  SharePayloadId.postId => context.t.post.action.copy_post_id,
};

String _shareTooltip(BuildContext context, SharePayloadId id) => switch (id) {
  SharePayloadId.image => context.t.post.action.share_image,
  SharePayloadId.original => context.t.post.action.share_original,
  SharePayloadId.video => context.t.post.action.share_video,
  SharePayloadId.booruLink => context.t.post.action.share_booru_link,
  SharePayloadId.sourceLink => context.t.post.action.share_source_link,
  SharePayloadId.imageLink => context.t.post.action.share_image_link,
  SharePayloadId.postId => context.t.post.action.share_post_id,
};

String _mediaError(BuildContext context, ShareMediaFailure failure) =>
    switch (failure) {
      ShareMediaFailure.network => context.t.post.action.share_network_error,
      ShareMediaFailure.unavailable =>
        context.t.post.action.share_media_unavailable,
      ShareMediaFailure.authentication =>
        context.t.post.action.share_authentication_error,
      ShareMediaFailure.storage => context.t.post.action.share_storage_error,
      ShareMediaFailure.unsupported =>
        context.t.post.action.share_unsupported_format,
      ShareMediaFailure.empty => context.t.post.action.share_empty_file,
      ShareMediaFailure.cancelled => context.t.post.action.share_cancelled,
    };
