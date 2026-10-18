// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/providers.dart';
import '../../../../router.dart';
import '../../../post/providers.dart';
import '../../../post/types.dart';
import '../../routes.dart';
import 'mixed_post_details_page.dart';
import 'post_page_presentation_scope.dart';

class CurrentPostDetailsPage<T extends Post> extends ConsumerWidget {
  const CurrentPostDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = InheritedDetailsContext.of<T>(context);
    if (payload.useMixedViewer) {
      return MixedPostDetailsPage(
        posts: payload.posts,
        initialIndex: payload.initialIndex,
        initialThumbnailUrl: payload.initialThumbnailUrl,
        scrollController: payload.scrollController,
        disclaimer: payload.dislclaimer,
        liveSource: payload.liveSource,
        fallbackConfig: payload.config,
        postRecoveryBuilder: _postRecoveryBuilder(ref),
      );
    }
    final booruBuilder = ref.watch(booruBuilderProvider(ref.watchConfigAuth));
    final builder = booruBuilder?.postDetailsPageBuilder;

    return builder != null
        ? builder(context, payload)
        : const UnimplementedPage();
  }
}

class PayloadPostDetailsPage<T extends Post> extends ConsumerWidget {
  const PayloadPostDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = InheritedDetailsContext.of<T>(context);
    final configSearch = payload.configSearch;

    if (payload.useMixedViewer) {
      return MixedPostDetailsPage(
        posts: payload.posts,
        initialIndex: payload.initialIndex,
        initialThumbnailUrl: payload.initialThumbnailUrl,
        scrollController: payload.scrollController,
        disclaimer: payload.dislclaimer,
        liveSource: payload.liveSource,
        fallbackConfig: payload.config,
        postRecoveryBuilder: _postRecoveryBuilder(ref),
      );
    }

    if (configSearch == null) {
      return const UnimplementedPage();
    }

    final booruBuilder = ref.watch(booruBuilderProvider(configSearch.auth));
    final builder = booruBuilder?.postDetailsPageBuilder;

    return builder != null
        ? builder(context, payload)
        : const UnimplementedPage();
  }
}

PostRecoveryBuilder _postRecoveryBuilder(WidgetRef ref) => (post, config) {
  if (post.id <= 0) return null;

  return () async {
    try {
      final result = await ref
          .read(originAwarePostRepoProvider(config))
          .getPost(NumericPostId(post.id))
          .run();
      return result.fold(
        (_) => const PostRecoveryFailure(
          PostPresentationFallbackReason.refreshFailed,
        ),
        (post) => post == null
            ? const PostRecoveryFailure(
                PostPresentationFallbackReason.removedUpstreamPost,
              )
            : PostRecoverySuccess(post),
      );
    } catch (_) {
      return const PostRecoveryFailure(
        PostPresentationFallbackReason.refreshFailed,
      );
    }
  };
};

class InheritedDetailsContext<T extends Post> extends InheritedWidget {
  const InheritedDetailsContext({
    required this.context,
    required super.child,
    super.key,
  });

  final DetailsRouteContext<T> context;

  static DetailsRouteContext<T> of<T extends Post>(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<InheritedDetailsContext<T>>();

    return widget?.context ??
        (throw Exception('No InheritedDetailsContext found in context'));
  }

  @override
  bool updateShouldNotify(InheritedDetailsContext<T> oldWidget) {
    return context != oldWidget.context;
  }
}
