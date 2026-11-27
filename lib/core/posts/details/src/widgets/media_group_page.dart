import '../../../../boorus/booru/types.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../../foundation/networking.dart';
import '../../../../configs/config/types.dart';
import '../../../../images/booru_image.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/types.dart';
import '../../../../content/groups/group_source_provider.dart';
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
import '../providers/group_reading_provider.dart';
import '../providers/providers.dart';
import '../types/media_group_checkpoint.dart';
import '../types/post_details.dart';
import '../types/viewer_entry.dart';
import 'post_details_controller.dart';
import 'post_details_item.dart';
import 'post_details_page_view_scope.dart';
import 'post_viewer_auto_comic_strip.dart';
import 'post_viewer_transformation_scope.dart';
import 'media_group_page_indicator.dart';

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
  Object? _sequenceKey;
  var _pagerIdentity = Object();
  ({GroupLoadKey key, int generation})? _reindex;
  Object? _completedCoverKey;

  @override
  void initState() {
    super.initState();
    widget.checkpoint.adoptMediaOrder = _adoptMediaOrder;
  }

  bool _adoptMediaOrder(
    GroupLoadKey key,
    GroupMembersState snapshot,
  ) {
    if (!mounted) return false;
    final oldMembers = ref
        .read(mediaGroupProvider(widget.entry))
        .members
        ?.members;
    final checkpoint = widget.checkpoint;
    final previousMember =
        checkpoint.memberKey ?? oldMembers?.firstOrNull?.memberKey;
    if (snapshot.members.firstOrNull?.memberKey != previousMember) {
      PostDetailsPageViewScope.of(context).synchronizeZoom(false);
    }
    final pages = _pages;
    if (pages == null || !pages.hasClients) return true;
    _reindex = (
      key: key,
      generation: snapshot.generation,
    );
    if (snapshot.members.isNotEmpty) pages.jumpToPage(0);
    final reindex = _reindex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reindex == reindex) _reindex = null;
    });
    return true;
  }

  void _finishCoverHandoff(Object key) {
    if (!mounted || key != _currentCoverKey || key == _completedCoverKey) {
      return;
    }
    setState(() => _completedCoverKey = key);
  }

  void _preload(ContentPreloadRequest source) {
    if (_preloadScheduled) return;
    _preloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScheduled = false;
      if (!mounted ||
          !NavigationActivity.of(context) ||
          PostDetailsPageViewScope.of(context).page != widget.index ||
          !ref.read(automaticMediaLoadingEnabledProvider)) {
        return;
      }
      final state = ref.read(mediaGroupProvider(widget.entry));
      final access = state.access;
      if (access?.key != source.access ||
          !identical(
            ref.read(contentAccessContextProvider(source.access)),
            access,
          )) {
        return;
      }
      final members = state.members?.members;
      final index = members == null ? null : widget.checkpoint.indexIn(members);
      if (members == null || index == null || state.failed) return;
      final config = access!.config!;
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
        itemCount: members.length,
        mediaBuilder: (page) {
          final post = state.postAt(page);
          if (post == null ||
              ref
                      .read(
                        contentPostVisibilityProvider((
                          access: access.key,
                          post: post,
                        )),
                      )
                      .asData
                      ?.value !=
                  true) {
            return null;
          }
          return viewerPreloadMedia(
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
    if (widget.checkpoint.adoptMediaOrder == _adoptMediaOrder) {
      widget.checkpoint.adoptMediaOrder = null;
    }
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

  Future<void> _retry(MediaGroupState state) async {
    ref.read(groupReadingProvider(widget.entry).notifier).cancelOrder();
    final key = state.loadKey;
    if (key == null) {
      if (state.access case final access?) {
        ref.invalidate(contentGroupSourceProvider(access.key));
      }
      return;
    }
    if (state.failed) {
      ref.invalidate(groupDetailsProvider(key.metadata));
      await ref.read(groupMembersProvider(key).notifier).refresh();
    } else {
      await ref.read(groupMembersProvider(key).notifier).retryNext();
    }
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
        final loadFailed = state.failed || state.members?.nextPageError != null;
        final unavailable =
            loadFailed ||
            (members != null && state.members?.next == null && index == null);
        // The first Work may already have a decoded timeline cover when its
        // Page manifest arrives. Keep that same cover element mounted over
        // the new PageView until a real Page image has painted.
        final cover =
            widget.entry.summary.cover ?? state.details?.summary.cover;
        final coverUrl = cover?.sample?.toString();
        final access = state.access;
        final selectedPost = index == null ? null : state.postAt(index);
        // Only a new manifest, media identity or access generation can reopen
        // the handoff; unrelated provider rebuilds preserve decoded pixels.
        final coverKey = (
          access?.key,
          state.members?.generation,
          index == null ? null : members?[index].memberKey,
          selectedPost == null ? null : postViewerIdentity(selectedPost),
          selectedPost?.sampleImageUrl,
          selectedPost?.originalImageUrl,
        );
        _currentCoverKey = coverKey;
        final showCover =
            widget.entry.contentReference.engine == BooruType.pixiv &&
            widget.entry.contentReference.sourceKey.startsWith('work:') &&
            autoLoad &&
            _completedCoverKey != coverKey &&
            !unavailable &&
            (index == null || state.details == null || selectedPost != null) &&
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
                    accessKey: access.key,
                    requireAccess: true,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            cover?.width != null && cover?.height != null
                            ? cover!.width! / cover.height!
                            : 1,
                        child: BooruImage(
                          config: access.config!.auth,
                          imageUrl: coverUrl,
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
          _preloader?.cancelAll();
          if (index == null && state.members?.next != null) _loadNext(state);
          final connection = loadFailed
              ? ref.watch(currentConnectivityProvider).asData?.value
              : null;
          final offline =
              connection != null &&
              (connection.isEmpty ||
                  connection.contains(ConnectivityResult.none));
          return withCover(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: outer.showAllUI,
              child: Center(
                child: unavailable
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.t.content_viewer.page_unavailable),
                          if (offline) Text(context.t.network.unavailable),
                          if (loadFailed && state.access != null)
                            TextButton(
                              onPressed: () => _retry(state),
                              child: Text(context.t.generic.action.retry),
                            ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          );
        }
        // The bounded occurrence checkpoint is the only reading-state owner.
        // PageStorage must not resurrect an evicted Work's previous Page.
        final sequenceKey = (state.loadKey, state.members?.generation);
        if (_sequenceKey != sequenceKey) {
          _sequenceKey = sequenceKey;
          final reindex = _reindex;
          if (reindex == null ||
              reindex.key != state.loadKey ||
              reindex.generation != state.members?.generation) {
            _pagerIdentity = Object();
            final oldPages = _pages;
            _pages = null;
            if (oldPages != null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => oldPages.dispose(),
              );
            }
          }
        }
        _pages ??= PageController(initialPage: index, keepPage: false);
        widget.checkpoint.pages = _pages;
        widget.checkpoint.navigate = (target) {
          ref.read(groupReadingProvider(widget.entry).notifier).cancelOrder();
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
        final active =
            outerIndex == widget.index && NavigationActivity.of(context);
        if (active && autoLoad && !state.failed) {
          final source = (auth: config.auth, access: state.access!.key);
          _preloader = ref.watch(
            contentOccurrencePreloadManagerProvider((
              source: source,
              occurrence: this,
            )),
          );
          ref.watch(mediaUrlResolverProvider(config.auth));
          _preload(source);
        } else {
          _preloader?.cancelAll();
        }
        final selectedMember = members[index];
        final position =
            widget.entry.contentReference.sourceKey.startsWith('work:')
            ? selectedMember.sourcePosition ?? index
            : index;
        final total = state.members?.sourceTotal ?? members.length;
        return withCover(
          Stack(
            fit: StackFit.expand,
            children: [
              CurrentBooruConfigScope(
                config: config,
                accessKey: state.access!.key,
                requireAccess: true,
                child: ValueListenableBuilder(
                  valueListenable: outer.zoom,
                  builder: (context, zoomed, _) => PageView.builder(
                    key: ValueKey((
                      widget.entry.occurrenceId,
                      state.access!.key,
                      _pagerIdentity,
                    )),
                    controller: _pages,
                    allowImplicitScrolling: true,
                    // The complete media frame routes drags to this pager or the
                    // outer pager. The transformed image cannot own that decision.
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    findChildIndexCallback: (key) {
                      if (key is! ValueKey<String>) return null;
                      final position = members.indexWhere(
                        (m) => m.memberKey == key.value,
                      );
                      return position < 0 ? null : position;
                    },
                    onPageChanged: (selected) {
                      if (_reindex != null) return;
                      ref
                          .read(groupReadingProvider(widget.entry).notifier)
                          .cancelOrder();
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
                        return GestureDetector(
                          key: ValueKey(member.memberKey),
                          behavior: HitTestBehavior.opaque,
                          onTap: outer.showAllUI,
                          child: Center(
                            child: Text(
                              context.t.content_viewer.page_unavailable,
                            ),
                          ),
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
                          active: active && pageIndex == index,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // The reading hint belongs to the media frame as pages slide.
              if (active && selectedPost != null && total > 1)
                Positioned.fill(
                  child: MediaGroupPageIndicator(
                    memberKey: selectedMember.memberKey,
                    page: position + 1,
                    total: total,
                    disableAnimation: ref
                        .watch(settingsProvider)
                        .reduceAnimations,
                  ),
                ),
              if (state.members?.nextPageError != null &&
                  index == members.length - 1)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 80),
                    child: TextButton.icon(
                      onPressed: () => _retry(state),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.t.generic.action.retry),
                    ),
                  ),
                ),
            ],
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
