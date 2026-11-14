import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../settings/providers.dart';
import '../../../../developer_options/providers.dart';
import '../../../listing/types.dart';
import '../../../post/types.dart';
import '../../../details_pageview/widgets.dart';
import '../../../media_preload/providers.dart';
import '../../../media_preload/types.dart';
import '../../../media_preload/src/viewer_preload_metadata.dart';
import '../../../../content/content_access_provider.dart';
import '../providers/media_group_provider.dart';
import '../providers/providers.dart';
import '../types/media_group_checkpoint.dart';
import '../types/post_details.dart';
import '../types/viewer_entry.dart';
import 'post_details_controller.dart';
import 'post_details_item.dart';
import 'post_details_page_view_scope.dart';
import 'post_viewer_auto_comic_strip.dart';
import 'post_viewer_transformation_scope.dart';

/// Only this media region owns the inner pager. The outer viewer retains
/// Details, its vertical transition, system chrome, overlay and Work paging.
class MediaGroupPage extends ConsumerStatefulWidget {
  const MediaGroupPage({
    required this.entry,
    required this.index,
    required this.checkpoint,
    required this.onSelected,
    required this.controllerForPost,
    required this.onControllerReleased,
    required this.onControllerAttached,
    this.routeActive = true,
    this.onDisplayed,
    super.key,
  });
  final GroupViewerEntry entry;
  final bool routeActive;
  final VoidCallback? onDisplayed;
  final int index;
  final MediaGroupCheckpoint checkpoint;
  final VoidCallback onSelected;
  final PostDetailsController<Post> Function(Post) controllerForPost;
  final ValueChanged<PostDetailsController<Post>> onControllerReleased;
  final ValueChanged<PostDetailsController<Post>> onControllerAttached;

  @override
  ConsumerState<MediaGroupPage> createState() => _MediaGroupPageState();
}

class _MediaGroupPageState extends ConsumerState<MediaGroupPage> {
  PageController? _pages;
  var _visited = false;
  var _preparing = false;
  var _restoreBatches = 0;
  PreloadManager? _preloader;
  final _directions = DirectionHistory();
  var _preloadScheduled = false;
  Object? _currentCoverKey;
  Object? _completedCoverKey;

  void _finishCoverHandoff(Object key) {
    if (!mounted || key != _currentCoverKey || key == _completedCoverKey) {
      return;
    }
    setState(() => _completedCoverKey = key);
  }

  void _preload(MediaGroupState state, int index) {
    if (_preloadScheduled) return;
    _preloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScheduled = false;
      if (!mounted ||
          !NavigationActivity.of(context) ||
          PostDetailsPageViewScope.of(context).page != widget.index ||
          !identical(
            ref.read(contentAccessContextProvider(state.access!.key)),
            state.access,
          )) {
        return;
      }
      final config = state.access!.config!;
      final resolver = ref.read(mediaUrlResolverProvider(config.auth));
      _preloader?.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(
          directionHistory: _directions,
          options: const PreloadStrategyOptions(
            defaultPreloadDistance: 2,
            preloadDisplayOnEntry: true,
            mediumConfidenceBoost: 0,
            highConfidenceBoost: 0,
          ),
        ),
        currentPage: index,
        itemCount: state.members!.members.length,
        mediaBuilder: (page) {
          final post = state.postAt(page);
          return post == null
              ? null
              : thumbnailOnlyViewerPreloadMedia(
                  post,
                  thumbnailUrl: post.sampleImageUrl,
                  displayUrl: resolver.resolveMediaUrl(post, config.viewer),
                );
        },
      );
    });
  }

  @override
  void dispose() {
    widget.checkpoint.navigate = null;
    _preloader?.cancelAll();
    if (identical(widget.checkpoint.pages, _pages)) {
      widget.checkpoint.pages = null;
    }
    _pages?.dispose();
    super.dispose();
  }

  void _loadNext(MediaGroupState state) {
    if (_preparing ||
        state.loadKey == null ||
        state.members?.next == null ||
        state.members?.nextPageError != null ||
        _restoreBatches >= 128) {
      return;
    }
    _preparing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted || !NavigationActivity.of(context)) return;
        _restoreBatches++;
        await ref
            .read(groupMembersProvider(state.loadKey!).notifier)
            .loadNext();
      } finally {
        if (mounted) setState(() => _preparing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final outer = PostDetailsPageViewScope.of(context);
    return ValueListenableBuilder(
      valueListenable: outer.currentPage,
      builder: (context, outerIndex, _) {
        _visited |= outerIndex == widget.index;
        widget.checkpoint.visited |= _visited;
        final autoLoad = ref.watch(automaticMediaLoadingEnabledProvider);
        final prepareNeighbor =
            widget.routeActive &&
            autoLoad &&
            (outerIndex - widget.index).abs() <= 1;
        if (!_visited && !prepareNeighbor) return const SizedBox.expand();
        final state = ref.watch(mediaGroupProvider(widget.entry));
        final members = state.members?.members;
        final index = members == null
            ? null
            : widget.checkpoint.indexIn(members);
        final unavailable =
            state.failed ||
            (members != null && state.members?.next == null && index == null);
        // The first Work may already have a decoded timeline cover when its
        // Page manifest arrives. Keep that same cover element mounted over
        // the new PageView until a real Page image has painted.
        final cover =
            widget.entry.summary.cover ?? state.details?.summary.cover;
        final coverUrl = cover?.sample?.toString();
        final access = state.access;
        final firstPost = index == null ? null : state.postAt(index);
        // Only a new manifest, media identity or access generation can reopen
        // the handoff; unrelated provider rebuilds preserve decoded pixels.
        final coverKey = (
          access?.key,
          state.members?.generation,
          index == null ? null : members?[index].memberKey,
          firstPost == null ? null : postViewerIdentity(firstPost),
          firstPost?.sampleImageUrl,
          firstPost?.originalImageUrl,
        );
        _currentCoverKey = coverKey;
        final showCover =
            autoLoad &&
            _completedCoverKey != coverKey &&
            !unavailable &&
            (index == null || state.details == null || firstPost != null) &&
            widget.checkpoint.memberKey == null &&
            access?.config != null &&
            coverUrl != null;
        Widget withCover(Widget page) => Stack(
          fit: StackFit.expand,
          children: [
            page,
            if (showCover)
              Positioned.fill(
                child: IgnorePointer(
                  child: CurrentBooruConfigScope(
                    config: access!.config!,
                    accessKey: access!.key,
                    requireAccess: true,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            cover?.width != null && cover?.height != null
                            ? cover!.width! / cover!.height!
                            : 1,
                        child: BooruImage(
                          config: access!.config!.auth,
                          imageUrl: coverUrl!,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        if (index == null || (state.details == null && !state.failed)) {
          if (index == null && state.members?.next != null) _loadNext(state);
          return withCover(
            Center(
              child: unavailable
                  ? Text(context.t.content_viewer.page_unavailable)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        // The bounded occurrence checkpoint is the only reading-state owner.
        // PageStorage must not resurrect an evicted Work's previous Page.
        _pages ??= PageController(initialPage: index, keepPage: false);
        widget.checkpoint.pages = _pages;
        widget.checkpoint.navigate = (target) {
          if (_pages?.hasClients ?? false) {
            _pages!.animateToPage(
              target,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        };
        if (index >= members!.length - 2) _loadNext(state);
        final config = state.access!.config!;
        if (outerIndex == widget.index && NavigationActivity.of(context)) {
          _preloader = ref.watch(
            contentOccurrencePreloadManagerProvider((
              source: (auth: config.auth, access: state.access!.key),
              occurrence: this,
            )),
          );
          _preload(state, index);
        } else {
          _preloader?.cancelAll();
        }
        return withCover(
          CurrentBooruConfigScope(
            config: config,
            accessKey: state.access!.key,
            requireAccess: true,
            child: ValueListenableBuilder(
              valueListenable: outer.zoom,
              builder: (context, zoomed, _) => PageView.builder(
                key: ValueKey((widget.entry.occurrenceId, state.access!.key)),
                controller: _pages,
                allowImplicitScrolling: true,
                // The complete media frame routes drags to this pager or the
                // outer pager. The transformed image cannot own that decision.
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                onPageChanged: (selected) {
                  _directions.addDirection(selected, index);
                  widget.checkpoint.select(members[selected]);
                  // Keep matrices bounded; neighboring widgets retain their own.
                  while (widget.checkpoint.transforms.length > 16) {
                    widget.checkpoint.transforms.remove(
                      widget.checkpoint.transforms.keys.first,
                    );
                  }
                  outer.synchronizeZoom(false);
                  setState(() {});
                  widget.onSelected();
                },
                itemBuilder: (context, pageIndex) {
                  final member = members[pageIndex];
                  final post = state.postAt(pageIndex);
                  if (post == null) {
                    return Center(
                      child: Text(context.t.content_viewer.page_unavailable),
                    );
                  }
                  return PostViewerOccurrence(
                    key: ValueKey(member.memberKey),
                    occurrence: member.memberKey,
                    checkpoints: widget.checkpoint.transforms,
                    child: _MediaPage(
                      key: ValueKey((member.memberKey, state.access!.key)),
                      post: post,
                      controller: widget.controllerForPost(post),
                      onControllerReleased: widget.onControllerReleased,
                      onControllerAttached: widget.onControllerAttached,
                      config: config,
                      outerIndex: widget.index,
                      onDisplayed: widget.onDisplayed,
                      onImageReady: pageIndex == index
                          ? () => _finishCoverHandoff(coverKey)
                          : null,
                      onImageUnavailable: pageIndex == index
                          ? () => _finishCoverHandoff(coverKey)
                          : null,
                      active:
                          outerIndex == widget.index &&
                          pageIndex == index &&
                          NavigationActivity.of(context),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaPage extends ConsumerStatefulWidget {
  const _MediaPage({
    required this.post,
    required this.controller,
    required this.onControllerReleased,
    required this.onControllerAttached,
    required this.config,
    required this.outerIndex,
    required this.active,
    this.onImageReady,
    this.onDisplayed,
    this.onImageUnavailable,
    super.key,
  });
  final Post post;
  final PostDetailsController<Post> controller;
  final ValueChanged<PostDetailsController<Post>> onControllerReleased;
  final ValueChanged<PostDetailsController<Post>> onControllerAttached;
  final BooruConfig config;
  final int outerIndex;
  final bool active;
  final VoidCallback? onImageReady;
  final VoidCallback? onDisplayed;
  final VoidCallback? onImageUnavailable;
  @override
  ConsumerState<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<_MediaPage> {
  final _transform = TransformationController();
  final _initial = ValueNotifier(true);
  Size? _contentSize;
  Size? _pendingSize;

  void _onImageSize(Size size) {
    if (size == _contentSize || size == _pendingSize) return;
    _pendingSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pendingSize == size) {
        setState(() {
          _contentSize = size;
          _pendingSize = null;
        });
      }
    });
  }

  PostDetailsController<Post> get _details => widget.controller;

  void _settle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _details.currentSettledPage.value = widget.active
          ? widget.outerIndex
          : null;
      _details.setNavigationActive(widget.active);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.onControllerAttached(_details);
    _settle();
  }

  @override
  void didUpdateWidget(_MediaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      widget.onControllerAttached(widget.controller);
      oldWidget.onControllerReleased(oldWidget.controller);
    }
    if (oldWidget.active != widget.active ||
        !identical(oldWidget.controller, widget.controller)) {
      _settle();
    }
  }

  @override
  void dispose() {
    widget.onControllerReleased(_details);
    _transform.dispose();
    _initial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolver = ref.watch(mediaUrlResolverProvider(widget.config.auth));
    final contentSize =
        _contentSize ?? Size(widget.post.width, widget.post.height);
    final media = PostDetails(
      data: PostDetailsData<Post>(posts: [widget.post], controller: _details),
      child: HeroMode(
        enabled: false,
        child: PostViewerTransformationViewport(
          child: PostViewerAutoComicStrip(
            index: widget.outerIndex,
            postId: widget.post.id,
            contentSize: contentSize,
            currentSettledPage: _details.currentSettledPage,
            enabled: ref
                .watch(imageViewerSettingsProvider)
                .autoAdjustComicStrips,
            child: PostDetailsItem<Post>(
              index: widget.outerIndex,
              post: widget.post,
              contentSize: _contentSize,
              allowOriginalImage: widget.active,
              onImageSize: _onImageSize,
              onImageReady: widget.onImageReady,
              onDisplayed: widget.onDisplayed,
              onImageUnavailable: widget.onImageUnavailable,
              placeholderMediaBuilder: (post) {
                final original =
                    _details.originalImagePostKeys.value.contains(
                      postViewerIdentity(post),
                    ) ||
                    resolver.resolveMediaUrl(post, widget.config.viewer) ==
                        post.originalImageUrl;
                // Originals already stage this uncropped sample as a full
                // intermediate, including its own decoded Page geometry.
                return GridThumbnailMedia(
                  url: original ? '' : post.sampleImageUrl,
                  aspectRatio: null,
                );
              },
              posts: [widget.post],
              detailsController: _details,
              transformController: _transform,
              isInitPageListenable: _initial,
              imageCacheManager: null,
              authConfig: widget.config.auth,
              viewerConfig: widget.config.viewer,
              gestureConfig: widget.config.postGestures,
              imageUrlBuilder: (post) => widget.active
                  ? resolver.resolveMediaUrl(post, widget.config.viewer)
                  : post.sampleImageUrl.isNotEmpty &&
                        post.sampleImageUrl != post.originalImageUrl
                  ? post.sampleImageUrl
                  : post.thumbnailImageUrl.isNotEmpty &&
                        post.thumbnailImageUrl != post.originalImageUrl
                  ? post.thumbnailImageUrl
                  : '',
              mediaAspectRatioBuilder: (post) =>
                  resolver.resolveMediaAspectRatio(post, widget.config.viewer),
              videoAspectRatioBuilder: (post) =>
                  resolver.resolveVideoAspectRatio(post, widget.config.viewer),
            ),
          ),
        ),
      ),
    );
    return ViewerMediaViewport.maybeOf(context)?.present(contentSize, media) ??
        media;
  }
}
