import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../../foundation/display.dart';
import '../../../../configs/config/types.dart';
import '../../../../router.dart';
import '../../../../settings/providers.dart';
import '../../../listing/providers.dart';
import '../../../post/types.dart';
import '../providers/providers.dart';
import '../types/post_details_swipe_mode.dart';
import '../widgets/lazy_post_details_pager.dart';
import '../widgets/post_details_page.dart';
import 'details_route_context.dart';

class LazyPostDetailsRouteContext {
  const LazyPostDetailsRouteContext({
    required this.source,
    required this.initialIndex,
    required this.config,
  });

  final LazyPostDetailsSource source;
  final int initialIndex;
  final BooruConfig config;
}

void goToLazyPostDetailsPageFromController<T extends Post>({
  required WidgetRef ref,
  required int initialIndex,
  required PostGridController<T> controller,
  required BooruConfig config,
}) {
  ref.router.push(
    '/post-list-details',
    extra: LazyPostDetailsRouteContext(
      source: LazyPostDetailsSource(
        changes: controller.itemsNotifier,
        postIds: () => [for (final post in controller.items) post.id],
        hasMore: () => controller.hasMore,
        fetchMore: controller.fetchMore,
      ),
      initialIndex: initialIndex,
      config: config,
    ),
  );
}

GoRoute lazyPostDetailsRoutes(Ref ref) => GoRoute(
  path: 'post-list-details',
  name: '/post-list-details',
  pageBuilder: (context, state) {
    if (state.extra case final LazyPostDetailsRouteContext data) {
      return MaterialPage(
        key: state.pageKey,
        child: _LazyPostDetailsPage(data: data),
      );
    }
    return MaterialPage(
      key: state.pageKey,
      child: InvalidPage(message: context.t.generic.errors.no_data),
    );
  },
);

class _LazyPostDetailsPage extends ConsumerWidget {
  const _LazyPostDetailsPage({required this.data});

  final LazyPostDetailsRouteContext data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swipeMode = ref.watch(
      imageViewerSettingsProvider.select((settings) => settings.swipeMode),
    );
    return LazyPostDetailsPager(
      source: data.source,
      initialIndex: data.initialIndex,
      axis: swipeMode == PostDetailsSwipeMode.vertical && !context.isLargeScreen
          ? Axis.vertical
          : Axis.horizontal,
      itemBuilder: (context, postId) => _LazyPostItem(
        postId: postId,
        config: data.config,
      ),
    );
  }
}

class _LazyPostItem extends ConsumerWidget {
  const _LazyPostItem({required this.postId, required this.config});

  final int postId;
  final BooruConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (NumericPostId(postId), config);
    return ref
        .watch(singlePostDetailsProvider(params))
        .when(
          data: (post) => post == null
              ? _errorPage(context, ref, params)
              : InheritedDetailsContext<Post>(
                  context: DetailsRouteContext<Post>(
                    initialIndex: 0,
                    posts: [post],
                    scrollController: null,
                    isDesktop: context.isLargeScreen,
                    hero: false,
                    initialThumbnailUrl: null,
                    config: config,
                  ),
                  child: const PayloadPostDetailsPage<Post>(),
                ),
          error: (_, _) => _errorPage(context, ref, params),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
  }

  Widget _errorPage(
    BuildContext context,
    WidgetRef ref,
    (NumericPostId, BooruConfig) params,
  ) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.t.generic.errors.no_data),
          TextButton(
            onPressed: () => ref.invalidate(singlePostDetailsProvider(params)),
            child: Text(context.t.generic.action.retry),
          ),
        ],
      ),
    ),
  );
}
