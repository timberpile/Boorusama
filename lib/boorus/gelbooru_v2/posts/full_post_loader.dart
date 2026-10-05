// Dart imports:
import 'dart:async';
import 'dart:collection';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/post/types.dart';
import '../gelbooru_v2_provider.dart';
import 'providers.dart';

class GelbooruV2FullPostLoader extends ConsumerStatefulWidget {
  const GelbooruV2FullPostLoader({
    required this.post,
    required this.child,
    super.key,
  });

  final Post post;
  final Widget child;

  @override
  ConsumerState<GelbooruV2FullPostLoader> createState() =>
      _GelbooruV2FullPostLoaderState();
}

class _GelbooruV2FullPostLoaderState
    extends ConsumerState<GelbooruV2FullPostLoader> {
  final _requestedPosts = HashSet<Post>.identity();

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfig;
    final thumbnailOnly =
        ref
            .watch(gelbooruV2Provider)
            .getCapabilitiesForSite(config.url)
            ?.posts
            ?.thumbnailOnly ??
        false;

    if (thumbnailOnly && widget.post.metadata != null) {
      _scheduleResolution(widget.post, config);
    }

    return widget.child;
  }

  void _scheduleResolution(Post post, BooruConfig config) {
    if (!_requestedPosts.add(post)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_resolve(post, config));
    });
  }

  Future<void> _resolve(Post post, BooruConfig config) async {
    try {
      final resolved = await ref.read(
        gelbooruV2PostProvider((NumericPostId(post.id), config)).future,
      );
      if (!mounted || resolved == null || resolved.id != post.id) return;

      final details = PostDetails.maybeOf<Post>(context);
      final index = details?.posts.indexWhere(
        (candidate) => identical(candidate, post),
      );
      if (details == null || index == null || index < 0) return;

      details.controller.replacePost(
        index,
        resolved.thumbnailImageUrl.isNotEmpty
            ? resolved
            : resolved.copyWith(
                core: PostCoreData.fromPost(
                  resolved,
                  thumbnailImageUrl: post.thumbnailImageUrl,
                ),
              ),
      );
    } catch (_) {
      // Keep the listing thumbnail when the detail page is unavailable.
    }
  }
}
