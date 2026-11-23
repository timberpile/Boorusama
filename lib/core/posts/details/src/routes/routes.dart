// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../router.dart';
import '../../../../settings/providers.dart';
import '../../../../settings/types.dart';
import '../../../post/types.dart';
import '../../../details_pageview/widgets.dart';
import '../providers/providers.dart';
import '../widgets/post_details_page.dart';
import 'details_route_context.dart';

GoRoute postDetailsRoutes(Ref ref) => GoRoute(
  path: 'details',
  name: '/details',
  pageBuilder: (buildContext, state) {
    final context = castOrNull<DetailsRouteContext>(state.extra);
    final settings = ref.read(settingsProvider);

    if (context == null) {
      return MaterialPage(
        child: InvalidPage(message: 'Invalid context: $context'),
      );
    }

    final widget = InheritedDetailsContext(
      context: context,
      child: const CurrentPostDetailsPage(),
    );

    return _detailsPageBuilder(
      buildContext,
      context.isDesktop,
      settings,
      state,
      widget,
    );
  },
);

GoRoute singlePostDetailsRoutes(Ref ref) => GoRoute(
  path: 'posts/:id',
  name: '/posts',
  pageBuilder: (buildContext, state) {
    final context = castOrNull<DetailsRouteContext>(state.extra);
    final segments = state.uri.pathSegments;
    final sourceId =
        context?.config?.id ??
        state.uri.queryParameters['_profile'] ??
        (segments.length > 2 &&
                segments[0] == '_nav' &&
                segments[1] == 'profile'
            ? segments[2]
            : null);
    final config = sourceId == null
        ? context?.config
        : ref
              .read(booruConfigProvider)
              .where((c) => c.id == sourceId)
              .firstOrNull;

    final postIdString = state.pathParameters['id'];
    final settings = ref.read(settingsProvider);
    final postId = postIdString != null ? PostId.from(postIdString) : null;

    if (postId == null || config == null) {
      return MaterialPage(
        child: InvalidPage(message: 'Invalid post Id: $postId'),
      );
    }

    final widget = PostDetailsDataLoadingTransitionPage(
      postId: postId,
      config: config,
      pageBuilder: (context, detailsContext) {
        final widget = InheritedDetailsContext(
          context: detailsContext,
          child: const PayloadPostDetailsPage(),
        );

        return widget;
      },
    );

    return _detailsPageBuilder(
      buildContext,
      context?.isDesktop ?? false,
      settings,
      state,
      widget,
    );
  },
);

Page<dynamic> _detailsPageBuilder(
  BuildContext buildContext,
  bool isDesktop,
  Settings settings,
  GoRouterState state,
  Widget widget,
) {
  if (settings.reduceAnimations ||
      MediaQuery.disableAnimationsOf(buildContext)) {
    return NoTransitionPage(
      key: state.pageKey,
      name: state.name,
      child: widget,
    );
  }
  if (isDesktop) {
    return FastFadePage(key: state.pageKey, name: state.name, child: widget);
  }
  return PostDetailsTransitionPage(
    key: state.pageKey,
    name: state.name,
    child: widget,
  );
}

class PostDetailsDataLoadingTransitionPage extends ConsumerWidget {
  const PostDetailsDataLoadingTransitionPage({
    required this.pageBuilder,
    required this.postId,
    required this.config,
    super.key,
  });

  final PostId postId;
  final BooruConfig config;

  final Widget Function(
    BuildContext context,
    DetailsRouteContext<Post> detailsContext,
  )
  pageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (postId, config);
    return ref
        .watch(singlePostDetailsProvider(params))
        .when(
          data: (post) {
            if (post == null) {
              return InvalidPage(message: 'Invalid post: $post');
            }

            final detailsContext = DetailsRouteContext(
              initialIndex: 0,
              posts: [post],
              scrollController: null,
              isDesktop: false,
              hero: false,
              initialThumbnailUrl: null,
              dislclaimer: 'Single post mode, swiping is disabled',
              config: config,
              useMixedViewer: true,
            );
            return pageBuilder(context, detailsContext);
          },
          error: (error, stackTrace) => InvalidPage(message: error.toString()),
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
  }
}

class PostDetailsTransitionPage<T> extends CustomTransitionPage<T> {
  PostDetailsTransitionPage({required super.child, super.name, super.key})
    : super(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 210),
        transitionsBuilder: (context, animation, secondary, child) =>
            ViewerRouteTransition(animation: animation, child: child),
      );
}
