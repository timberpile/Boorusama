import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../anime-pictures/posts/providers.dart';
import '../anime-pictures/downloads/url_provider.dart';
import '../hybooru/posts/providers.dart';
import '../../foundation/riverpod/riverpod.dart';
import '../../core/boorus/booru/types.dart';
import '../../core/configs/manage/providers.dart';
import '../../core/posts/post/providers.dart';
import '../../core/configs/config/types.dart';
import '../../core/posts/post/types.dart';
import '../../core/posts/details/types.dart';

/// The two engines already expose bounded, source-scoped detail endpoints.
/// Only the current opened listing post enters this provider.
final sourcePostDetailProvider = FutureProvider.autoDispose
    .family<Post?, (BooruConfig, int)>((ref, request) async {
      ref.cacheFor(const Duration(seconds: 30));
      final (config, id) = request;
      final Post? post;
      if (config.auth.booruType == BooruType.animePictures) {
        post = await ref.watch(
          animePicturesResolvedPostProvider((config.auth, id)).future,
        );
      } else if (config.auth.booruType == BooruType.hybooru) {
        final result = await ref
            .read(hybooruPostRepoProvider(config.search))
            .getPost(NumericPostId(id))
            .run();
        post = result.fold((_) => null, (post) => post);
      } else {
        return null;
      }
      return post?.copyWith(origin: postOriginFromConfig(config));
    });

class SourcePostDetailLoader extends ConsumerStatefulWidget {
  const SourcePostDetailLoader({
    required this.post,
    required this.child,
    super.key,
  });
  final Post post;
  final Widget child;

  @override
  ConsumerState<SourcePostDetailLoader> createState() =>
      _SourcePostDetailLoaderState();
}

class _SourcePostDetailLoaderState
    extends ConsumerState<SourcePostDetailLoader> {
  var _scheduled = false;
  var _loading = false;
  Post? _requested;
  BooruConfig? _requestedConfig;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(currentReadOnlyBooruConfigProvider);
    final needsResolution =
        widget.post.metadata != null ||
        (config.auth.booruType == BooruType.animePictures &&
            ref
                    .read(
                      animePicturesDownloadFileUrlExtractorProvider(
                        config.auth,
                      ),
                    )
                    .cookieForMediaUrl(widget.post.originalImageUrl) ==
                null);
    if (!_scheduled &&
        !_loading &&
        needsResolution &&
        (!identical(widget.post, _requested) || config != _requestedConfig)) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted)
          unawaited(
            _resolve(widget.post, config),
          );
      });
    }
    return widget.child;
  }

  Future<void> _resolve(Post post, BooruConfig config) async {
    _loading = true;
    _requested = post;
    _requestedConfig = config;
    try {
      final resolved = await ref.read(
        sourcePostDetailProvider((config, post.id)).future,
      );
      if (!mounted ||
          resolved == null ||
          resolved.id != post.id ||
          !identical(widget.post, post) ||
          !ref.read(booruConfigProvider).contains(config) ||
          ref.read(currentReadOnlyBooruConfigProvider) != config)
        return;
      final details = PostDetails.maybeOf<Post>(context);
      final index = details?.posts.indexWhere(
        (candidate) => identical(candidate, post),
      );
      if (details != null && index != null && index >= 0)
        details.controller.replacePost(index, resolved);
    } catch (_) {
      // Keep usable listing media and unknown facts when offline or restricted.
    } finally {
      _loading = false;
      if (mounted &&
          (!identical(widget.post, _requested) ||
              ref.read(currentReadOnlyBooruConfigProvider) != _requestedConfig))
        setState(() {});
    }
  }
}
