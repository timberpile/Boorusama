import 'viewer_navigation_scope.dart';
import '../types/viewer_entry.dart';
import '../widgets/group_viewer_scope.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../../foundation/display.dart';
import '../../../../configs/config/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../router.dart';
import '../../../../navigation/destination_profile_scope.dart';
import '../../../../navigation/page_source_context.dart';
import '../../../listing/providers.dart';
import '../../../listing/src/types/page_mode.dart';
import '../../../post/types.dart';
import 'details_route_context.dart';
import 'post_details_live_source.dart';

void goToPostDetailsPageFromPosts<T extends Post>({
  required WidgetRef ref,
  required List<T> posts,
  required int initialIndex,
  required String? initialThumbnailUrl,
  AutoScrollController? scrollController,
  BooruConfig? config,
}) => goToPostDetailsPageCore(
  ref: ref,
  posts: posts,
  initialIndex: initialIndex,
  scrollController: scrollController,
  initialThumbnailUrl: initialThumbnailUrl,
  hero: false,
  config: config,
);

void goToPostDetailsPageFromController<T extends Post>({
  required WidgetRef ref,
  required int initialIndex,
  required PostGridController<T> controller,
  required String? initialThumbnailUrl,
  AutoScrollController? scrollController,
  BooruConfig? config,
  bool hero = true,
  bool Function()? canContinue,
}) {
  final projection = ViewerNavigationScope.maybeOf(ref.context);
  if (projection != null) {
    projection.open(initialIndex, initialThumbnailUrl);
    return;
  }
  final group = GroupViewerScope.maybeOf(ref.context);
  final sourceConfig = config ?? ref.readConfig;
  final binding =
      group?.entry.source ??
      (sourceConfig.anonymousReadScope == null
          ? null
          : ViewerSourceBinding.publicRead(
              PostOrigin.fromSource(
                booruType: sourceConfig.auth.booruType,
                booruId: 0,
                source: sourceConfig.url,
              ),
            ));
  List<ViewerEntry> boundEntries() => [
    for (final (index, post) in controller.items.indexed)
      PostViewerEntry(post: post, occurrenceId: index, source: binding),
  ];
  final live = PostDetailsLiveSource(
    changes: controller,
    posts: () => controller.items,
    hasMore: () =>
        (canContinue?.call() ?? true) &&
        controller.pageMode == PageMode.infinite &&
        controller.hasMore,
    loading: () => controller.loadingMore,
    failed: () => controller.errors.value != null,
    fetchMore: () async {
      if (canContinue?.call() ?? true) {
        await controller.fetchMore(canStart: canContinue);
      }
    },
  );
  goToPostDetailsPageCore(
    ref: ref,
    posts: controller.items.toList(),
    initialIndex: initialIndex,
    scrollController: scrollController,
    initialThumbnailUrl: initialThumbnailUrl,
    hero: hero,
    config: config,
    liveSource: binding == null ? live : null,
    entries: binding == null ? null : boundEntries(),
    entrySource: binding == null
        ? null
        : ViewerEntryLiveSource(
            changes: controller,
            entries: boundEntries,
            pagination: live,
          ),
  );
}

void goToPostDetailsPageCore<T extends Post>({
  required WidgetRef ref,
  required List<T> posts,
  required int initialIndex,
  required bool hero,
  required String? initialThumbnailUrl,
  AutoScrollController? scrollController,
  PostDetailsLiveSource? liveSource,
  List<ViewerEntry>? entries,
  ViewerEntryLiveSource? entrySource,
  BooruConfig? config,
}) {
  ref.pushRoute(
    Uri(
      path: '/details',
    ).toString(),
    extra: DetailsRouteContext(
      initialIndex: initialIndex,
      posts: posts,
      scrollController: scrollController,
      isDesktop: ref.context.isLargeScreen,
      hero: hero,
      initialThumbnailUrl: initialThumbnailUrl,
      // Preserve the profile that owns this listing. The mixed viewer still
      // resolves every post by origin first, but this gives it an exact
      // fallback for older rows and duplicate profiles on the same host.
      config:
          config ??
          (DestinationScope.maybeOf(ref.context) != null &&
                  ref.read(explicitPageSourceProvider) == null
              ? null
              : ref.readConfig),
      useMixedViewer: true,
      liveSource: liveSource,
      entries: entries,
      entrySource: entrySource,
    ),
  );
}

void goToSinglePostDetailsPage<T extends Post>({
  required WidgetRef ref,
  required PostId postId,
  required BooruConfig config,
}) {
  ref.pushRoute(
    Uri(
      path: '/posts/$postId',
    ).toString(),
    extra: DetailsRouteContext(
      initialIndex: 0,
      // ignore: prefer_const_literals_to_create_immutables
      posts: <T>[],
      scrollController: null,
      isDesktop: ref.context.isLargeScreen,
      hero: false,
      initialThumbnailUrl: null,
      config: config,
    ),
  );
}
