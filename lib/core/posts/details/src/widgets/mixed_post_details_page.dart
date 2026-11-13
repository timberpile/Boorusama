import 'package:foundation/performance.dart';

import '../../../../../foundation/performance/performance_navigation.dart';

// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../artists/types.dart';
import '../../../../content/groups/group_capability.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../configs/config/types.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../developer_options/providers.dart';
import 'group_viewer_scope.dart';
import '../../../../notes/note/widgets.dart';
import '../../../../settings/providers.dart';
import '../../../details_parts/types.dart';
import '../../../details_pageview/widgets.dart';
import '../../../details_parts/widgets.dart';
import '../../../post/types.dart';
import '../../../sources/types.dart';
import '../providers/providers.dart';
import '../providers/viewer_source_access_provider.dart';
import '../routes/post_details_live_source.dart';
import '../types/inherited_post.dart';
import '../types/post_details.dart';
import '../types/viewer_entry.dart';
import '../types/media_group_checkpoint.dart';
import '../providers/media_group_provider.dart';
import 'media_group_page.dart';
import 'media_group_actions.dart';
import 'media_group_page_indicator.dart';
import 'native_metadata_selection.dart';
import 'viewer_entry_content.dart';
import 'post_details_page_view_scope.dart';
import 'post_details_actions.dart';
import 'post_details_controller.dart';
import 'post_details_image_preloader.dart';
import 'post_details_item.dart';
import 'post_details_notes.dart';
import 'post_details_page_scaffold.dart';
import 'post_details_scope.dart';
import 'post_page_presentation_scope.dart';

sealed class PostRecoveryResult {
  const PostRecoveryResult();
}

final class PostRecoverySuccess extends PostRecoveryResult {
  const PostRecoverySuccess(this.post);

  final Post post;
}

final class PostRecoveryFailure extends PostRecoveryResult {
  const PostRecoveryFailure(this.reason);

  final PostPresentationFallbackReason reason;
}

typedef PostRecoveryCallback = Future<PostRecoveryResult> Function();
typedef PostRecoveryBuilder = PostRecoveryCallback? Function(
  Post post,
  BooruConfig config,
);

class MixedPostDetailsPage extends StatefulWidget {
  const MixedPostDetailsPage({
    required this.posts,
    required this.initialIndex,
    required this.initialThumbnailUrl,
    required this.scrollController,
    required this.disclaimer,
    this.fallbackUiBuilderDecorator,
    this.postRecoveryBuilder,
    this.fallbackConfig,
    this.liveSource,
    this.entries,
    this.entrySource,
    super.key,
  }) : assert(
         (entries?.length ?? posts.length) > 0,
         'Mixed viewer requires entries',
       ),
       assert(
         initialIndex >= 0 && initialIndex < (entries?.length ?? posts.length),
         'Initial index must reference a displayed viewer entry',
       );

  final List<Post> posts;
  final List<ViewerEntry>? entries;
  final ViewerEntryLiveSource? entrySource;
  final int initialIndex;
  final String? initialThumbnailUrl;
  final AutoScrollController? scrollController;
  final String? disclaimer;
  final PostDetailsUIBuilder Function(PostDetailsUIBuilder, Post)?
  fallbackUiBuilderDecorator;
  final PostRecoveryBuilder? postRecoveryBuilder;
  final BooruConfig? fallbackConfig;
  final PostDetailsLiveSource? liveSource;

  @override
  State<MixedPostDetailsPage> createState() => _MixedPostDetailsPageState();
}

class _MixedPostDetailsPageState extends State<MixedPostDetailsPage> {
  static const _emptyPageBudget = 3;
  static const _emptyPageCooldown = Duration(milliseconds: 150);

  late final ViewerEntrySequence? _sequence = widget.entries == null
      ? null
      : ViewerEntrySequence(widget.entries!);
  late final List<Post> _posts = _sequence?.posts ?? widget.posts.toList();
  int get _pageCount => _sequence?.entries.length ?? _posts.length;
  late final Set<String> _knownPosts = {
    for (final post in _posts) postViewerIdentity(post),
  };
  late int _currentIndex = widget.initialIndex;
  var _searchingForVisiblePost = false;
  var _needsManualLoadMore = false;

  @override
  void initState() {
    super.initState();
    widget.liveSource?.changes.addListener(_onLiveSourceChanged);
    widget.entrySource?.changes.addListener(_onEntrySourceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNearEnd(widget.initialIndex);
    });
  }

  @override
  void dispose() {
    widget.liveSource?.changes.removeListener(_onLiveSourceChanged);
    widget.entrySource?.changes.removeListener(_onEntrySourceChanged);
    super.dispose();
  }

  void _onEntrySourceChanged() {
    if (!mounted) return;
    setState(() {
      final before = _pageCount;
      _sequence?.append(widget.entrySource!.entries());
      if (_pageCount > before) _needsManualLoadMore = false;
    });
  }

  PostDetailsLiveSource? get _source =>
      widget.entrySource?.pagination ?? widget.liveSource;

  void _onLiveSourceChanged() {
    final source = _source;
    if (source == null) return;
    final added = [
      for (final post in source.posts())
        if (_knownPosts.add(postViewerIdentity(post))) post,
    ];
    setState(() {
      _posts.addAll(added);
      if (added.isNotEmpty) _needsManualLoadMore = false;
    });
  }

  void _loadNearEnd(int index) {
    final pageChanged = index != _currentIndex;
    _currentIndex = index;
    if (_needsManualLoadMore && !pageChanged) return;
    if (_needsManualLoadMore) {
      setState(() => _needsManualLoadMore = false);
    }
    _startNearEndLoad();
  }

  void _startNearEndLoad({bool allowFailed = false}) {
    final source = _source;
    if (source == null ||
        !source.hasMore() ||
        (_searchingForVisiblePost || (source.failed() && !allowFailed)) ||
        _currentIndex < _pageCount - 2) {
      return;
    }
    setState(() => _searchingForVisiblePost = true);
    unawaited(_fetchUntilVisible(source));
  }

  Future<void> _fetchUntilVisible(PostDetailsLiveSource source) async {
    final initialCount = _pageCount;
    var attempts = 0;
    var interrupted = false;
    try {
      while (_isActiveRoute &&
          attempts < _emptyPageBudget &&
          source.hasMore() &&
          _currentIndex >= _pageCount - 2) {
        attempts++;
        try {
          await source.fetchMore();
        } catch (_) {
          interrupted = true;
          break;
        }
        if (!_isActiveRoute ||
            _pageCount > initialCount ||
            source.failed() ||
            !source.hasMore() ||
            _currentIndex < _pageCount - 2) {
          break;
        }
        if (attempts < _emptyPageBudget) {
          await Future<void>.delayed(_emptyPageCooldown);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _searchingForVisiblePost = false;
          _needsManualLoadMore =
              (attempts == _emptyPageBudget ||
                  interrupted ||
                  !_isActiveRoute) &&
              _pageCount == initialCount &&
              source.hasMore() &&
              !source.failed() &&
              _currentIndex >= _pageCount - 2;
        });
      }
    }
  }

  void _retryLoading() {
    _startNearEndLoad(allowFailed: true);
  }

  void _continueLoading() {
    if (!_needsManualLoadMore) return;
    setState(() => _needsManualLoadMore = false);
    _startNearEndLoad();
  }

  bool get _isActiveRoute =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  Widget build(BuildContext context) => PerformanceScreenScope(
    screen: PerfScreen.postViewer,
    priority: 2,
    child: PostDetailsScope<Post>(
      initialIndex: widget.initialIndex,
      initialThumbnailUrl: widget.initialThumbnailUrl,
      posts: _posts,
      sequence: _sequence,
      dislclaimer: widget.disclaimer,
      scrollController: widget.scrollController,
      child: _MixedPostDetailsView(
        sequence: _sequence,
        fallbackUiBuilderDecorator: widget.fallbackUiBuilderDecorator,
        postRecoveryBuilder: widget.postRecoveryBuilder,
        fallbackConfig: widget.fallbackConfig,
        nextLoading: _searchingForVisiblePost || (_source?.loading() ?? false),
        nextFailed:
            (_source?.hasMore() ?? false) && (_source?.failed() ?? false),
        nextCanLoad: _needsManualLoadMore && (_source?.hasMore() ?? false),
        onRetryNext: _retryLoading,
        onLoadMoreNext: _continueLoading,
        onPageChanged: _loadNearEnd,
      ),
    ),
  );
}

class _MixedPostDetailsView extends ConsumerStatefulWidget {
  const _MixedPostDetailsView({
    required this.fallbackUiBuilderDecorator,
    required this.postRecoveryBuilder,
    required this.fallbackConfig,
    required this.nextLoading,
    required this.nextFailed,
    required this.nextCanLoad,
    required this.onRetryNext,
    required this.onLoadMoreNext,
    required this.onPageChanged,
    this.sequence,
  });

  final PostDetailsUIBuilder Function(PostDetailsUIBuilder, Post)?
  fallbackUiBuilderDecorator;
  final PostRecoveryBuilder? postRecoveryBuilder;
  final BooruConfig? fallbackConfig;
  final bool nextLoading;
  final bool nextFailed;
  final bool nextCanLoad;
  final VoidCallback onRetryNext;
  final VoidCallback onLoadMoreNext;
  final ValueChanged<int> onPageChanged;
  final ViewerEntrySequence? sequence;

  @override
  ConsumerState<_MixedPostDetailsView> createState() =>
      _MixedPostDetailsViewState();
}

class _MixedPostDetailsViewState extends ConsumerState<_MixedPostDetailsView> {
  // Presentation wrappers change when the selected outer Post/Work changes.
  // Keep the pager and its decoded neighboring media mounted across this swap.
  final _viewerScaffoldKey = GlobalKey();
  final _transformController = TransformationController();
  PostDetailsPageViewController? _mediaPager;

  void _mediaPageChanged() {
    if (mounted) {
      _scheduleMediaCleanup();
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pager = PostDetailsPageViewScope.of(context);
    if (_mediaPager != pager) {
      _mediaPager?.currentPage.removeListener(_mediaPageChanged);
      _mediaPager = pager;
      pager.currentPage.addListener(_mediaPageChanged);
    }
  }

  final _mediaCheckpoints = <Object, MediaGroupCheckpoint>{};
  final _mediaControllers = <Object, PostDetailsController<Post>>{};
  // Old/new media subtrees can overlap while the shared presentation rebuilds.
  // Only the last mounted Page may release an unselected controller.
  final _mediaControllerUsers = <PostDetailsController<Post>, int>{};
  final _selectedMediaControllers = <int, PostDetailsController<Post>>{};
  final _pendingMediaPosts = <PostDetailsController<Post>, (int, Post)>{};
  var _disposing = false;
  var _mediaCleanupScheduled = false;

  void _scheduleMediaCleanup() {
    if (_mediaCleanupScheduled || _disposing) return;
    _mediaCleanupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mediaCleanupScheduled = false;
      if (!mounted || _disposing) return;
      final replacements = Map.of(_pendingMediaPosts);
      _pendingMediaPosts.clear();
      for (final replacement in replacements.entries) {
        final (index, post) = replacement.value;
        replacement.key.replacePost(index, post);
      }
      final pager = _mediaPager!;
      final retained = pager.retainedStatePages
          .map((index) => widget.sequence?.entries[index].occurrenceId)
          .toSet();
      _mediaCheckpoints.removeWhere((key, _) => !retained.contains(key));
      _selectedMediaControllers.removeWhere(
        (index, _) => !pager.retainsStateFor(index),
      );
      final selected = _selectedMediaControllers.values.toSet();
      _mediaControllers.removeWhere((_, controller) {
        if (_mediaControllerUsers.containsKey(controller) ||
            selected.contains(controller)) {
          return false;
        }
        controller.dispose();
        return true;
      });
    });
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('mediaCheckpoints', _mediaCheckpoints.length))
      ..add(
        IntProperty(
          'selectedMediaControllers',
          _selectedMediaControllers.length,
        ),
      )
      ..add(IntProperty('mediaControllers', _mediaControllers.length))
      ..add(
        IntProperty('mountedMediaControllers', _mediaControllerUsers.length),
      );
  }

  Post? _mediaPostAt(int index, {bool includePrepared = false}) {
    if (!_hasMediaPager(index)) return null;
    final entry = widget.sequence!.entries[index] as GroupViewerEntry;
    if (!includePrepared &&
        index != _mediaPager?.page &&
        !(_mediaCheckpoints[entry.occurrenceId]?.visited ?? false)) {
      return null;
    }
    final state = ref.read(mediaGroupProvider(entry));
    final members = state.members?.members;
    final selected = members == null
        ? null
        : _checkpoint(entry).indexIn(members);
    return selected == null ? null : state.postAt(selected);
  }

  PostDetailsData<Post> _mediaDetails(
    int index,
    Post post, {
    bool selected = true,
  }) {
    final entry = widget.sequence!.entries[index] as GroupViewerEntry;
    final access = ref.read(mediaGroupProvider(entry)).access!;
    final key = (entry.occurrenceId, access.key, postViewerIdentity(post));
    final controller = _mediaControllers.putIfAbsent(
      key,
      () => PostDetailsController<Post>(
        posts: [post],
        initialPage: index,
        postIndexForPage: (page) => page == index ? 0 : null,
        scrollController: null,
        initialThumbnailUrl: null,
        dislclaimer: null,
        reduceAnimations: ref.read(settingsProvider).reduceAnimations,
        doubleTapSeekDuration: ref
            .read(imageViewerSettingsProvider)
            .doubleTapSeekDuration,
      ),
    );
    // Group hydration can replace URLs/metadata without changing Page identity.
    // Coalesce controller publication after build, preserving its reading state.
    if (!identical(controller.posts.single, post)) {
      _pendingMediaPosts[controller] = (index, post);
    } else {
      _pendingMediaPosts.remove(controller);
    }
    if (selected) _selectedMediaControllers[index] = controller;
    _scheduleMediaCleanup();
    return PostDetailsData(posts: controller.posts, controller: controller);
  }

  void _retainMediaController(PostDetailsController<Post> controller) {
    _mediaControllerUsers.update(
      controller,
      (users) => users + 1,
      ifAbsent: () => 1,
    );
  }

  void _releaseMediaController(
    PostDetailsController<Post> controller,
  ) {
    final users = _mediaControllerUsers[controller];
    if (users == null) return;
    if (users > 1) {
      _mediaControllerUsers[controller] = users - 1;
      return;
    }
    _mediaControllerUsers.remove(controller);
    // Toolbar and overlapping media consumers detach during the same frame.
    // Remove retention independently, then dispose only after the final detach.
    _scheduleMediaCleanup();
  }

  Widget? _pageIndicator(int index) {
    if (!_hasMediaPager(index)) return null;
    final entry = widget.sequence!.entries[index] as GroupViewerEntry;
    final state = ref.read(mediaGroupProvider(entry));
    final members = state.members?.members;
    final selected = members == null
        ? null
        : _checkpoint(entry).indexIn(members);
    final total = state.members?.sourceTotal ?? members?.length ?? 0;
    if (selected == null || total < 2) return null;
    return MediaGroupPageIndicator(
      key: ValueKey((entry.occurrenceId, state.access?.key)),
      memberKey: members![selected].memberKey,
      page: (members[selected].sourcePosition ?? selected) + 1,
      total: total,
      disableAnimation: ref.read(settingsProvider).reduceAnimations,
    );
  }

  bool _hasMediaPager(int index) {
    final entry = widget.sequence?.entries[index];
    if (entry is! GroupViewerEntry) return false;
    final presentation = ref
        .read(booruGroupCapabilityProvider(entry.contentReference.engine))
        ?.presentation;
    return presentation != null &&
        presentation.supports(entry.summary) &&
        presentation.layoutFor(entry.summary) == GroupLayout.mediaPager;
  }

  MediaGroupCheckpoint _checkpoint(GroupViewerEntry entry) =>
      _mediaCheckpoints.putIfAbsent(
        entry.occurrenceId,
        () => MediaGroupCheckpoint(memberKey: entry.initialMemberKey),
      );

  MediaPageNavigation? _mediaNavigation(int index) {
    if (!_hasMediaPager(index)) return null;
    final entry = widget.sequence!.entries[index] as GroupViewerEntry;
    final checkpoint = _checkpoint(entry);
    if (index != _mediaPager?.page &&
        !(_mediaCheckpoints[entry.occurrenceId]?.visited ?? false)) {
      return const MediaPageNavigation();
    }
    final state = ref.read(mediaGroupProvider(entry));
    final members = state.members?.members;
    final selected = members == null ? null : checkpoint.indexIn(members);
    if (selected == null &&
        !state.failed &&
        state.members?.nextPageError == null &&
        (members == null || state.members?.next != null)) {
      // Loading/restoring a Page does not prove either Work boundary.
      return const MediaPageNavigation();
    }
    final pager = PostDetailsPageViewScope.of(context);
    final previousEntry = index > 0
        ? () => unawaited(pager.previousPage())
        : null;
    final nextEntry = index + 1 < widget.sequence!.entries.length
        ? () => unawaited(pager.nextPage())
        : null;
    final atStart = selected == null || selected == 0;
    final atEnd =
        selected == null ||
        (selected + 1 == members!.length &&
            state.members!.next == null &&
            state.members!.nextPageError == null);
    return MediaPageNavigation(
      pageController: () => checkpoint.pages,
      atStart: atStart,
      atEnd: atEnd,
      previousId: atStart
          ? index > 0
                ? ('entry', index - 1)
                : null
          : (entry.occurrenceId, members![selected - 1].memberKey),
      nextId: atEnd
          ? nextEntry == null
                ? null
                : ('entry', index + 1)
          : selected + 1 < members.length
          ? (entry.occurrenceId, members[selected + 1].memberKey)
          : null,
      onPrevious: atStart
          ? previousEntry
          : () => checkpoint.navigate?.call(selected - 1),
      onNext: atEnd
          ? nextEntry
          : selected + 1 < members.length
          ? () => checkpoint.navigate?.call(selected + 1)
          : null,
    );
  }

  final _isInitPage = ValueNotifier(true);
  final _fallbackReasons = <int, PostPresentationFallbackReason>{};
  final _recovering = <int>{};
  final _automaticRecoveryAttempted = <int>{};

  @override
  void dispose() {
    _disposing = true;
    _mediaPager?.currentPage.removeListener(_mediaPageChanged);
    for (final controller in _mediaControllers.values) {
      controller.dispose();
    }
    _transformController.dispose();
    _isInitPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = PostDetails.maybeOf<Post>(context);
    final pager = PostDetailsPageViewScope.of(context);
    // The active occurrence keeps its source observers alive while metadata
    // and media compose into separate regions of the shared viewer.
    final entry = widget.sequence?.entries[pager.page];
    if (entry is GroupViewerEntry && _hasMediaPager(pager.page)) {
      ref.watch(mediaGroupProvider(entry));
    }
    return NativeMetadataSelectionScope(
      child: MixedPostDetailsImagePreloader(
        posts: details?.posts ?? const [],
        sequence: widget.sequence,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            pager.currentPage,
            if (details != null) details.controller.currentPost,
          ]),
          builder: (context, _) {
            final sequence = widget.sequence;
            final post = sequence == null
                ? details!.controller.currentPost.value
                : sequence.postAt(pager.page) ?? _mediaPostAt(pager.page);
            if (post == null) {
              _selectedMediaControllers.remove(pager.page);
              _scheduleMediaCleanup();
            }
            final activeDetails = _hasMediaPager(pager.page) && post != null
                ? _mediaDetails(pager.page, post)
                : details;
            return PostPagePresentationScope(
              post: post,
              sourceBinding: widget.sequence?.entries[pager.page].source,
              fallbackConfig: widget.fallbackConfig,
              groupBuilder: (context) => CurrentPostDetailsNotes(
                post: null,
                viewerConfig: BooruConfig.empty.viewer,
                authConfig: BooruConfig.empty.auth,
                enabled: false,
                child: Stack(children: [_buildGroupViewer(context, details)]),
              ),
              builder: (context, ref, presentation) => _buildViewer(
                context,
                ref,
                activeDetails!,
                presentation,
                regularDetails: details,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _entryItem(
    BuildContext context,
    int index,
  ) {
    final entry = widget.sequence?.entries[index];
    if (entry is GroupViewerEntry && _hasMediaPager(index)) {
      return KeyedSubtree(
        key: PageStorageKey(entry.occurrenceId),
        child: MediaGroupPage(
          // Preserve the entire decoded Work media subtree if the selected
          // presentation reparents its page wrapper in the same frame.
          key: GlobalObjectKey(_checkpoint(entry)),
          entry: entry,
          index: index,
          routeActive: NavigationActivity.of(this.context),
          checkpoint: _checkpoint(entry),
          onSelected: () => setState(() {}),
          controllerForPost: (post) =>
              _mediaDetails(index, post, selected: false).controller,
          onControllerAttached: _retainMediaController,
          onControllerReleased: (controller) =>
              _releaseMediaController(controller),
        ),
      );
    }
    if (entry != null && entry is! PostViewerEntry) {
      return ViewerEntryContent(
        key: PageStorageKey(entry.occurrenceId),
        entry: entry,
        index: index,
      );
    }
    throw StateError('Expected a group viewer entry');
  }

  Widget _buildGroupViewer(
    BuildContext context,
    PostDetailsData<Post>? details,
  ) => PostDetailsPageScaffold<Post>(
    key: _viewerScaffoldKey,
    sequence: widget.sequence,
    hasMediaPager: _hasMediaPager,
    mediaNavigationBuilder: _mediaNavigation,
    pagePostBuilder: _mediaPostAt,
    pageIndicatorBuilder: _pageIndicator,
    pageWrapperBuilder: (context, index, child) =>
        _wrapPage(context, index, child, details),
    controller: details?.controller,
    posts: details?.posts ?? const [],
    transformController: _transformController,
    isInitPage: _isInitPage,
    gestureConfig: null,
    layoutConfig: null,
    postGestureHandlerBuilder: null,
    uiBuilder: _groupSummaryUiBuilder,
    preferredParts: _groupSummaryDetailsParts,
    actions: const [],
    nextLoading: widget.nextLoading,
    nextFailed: widget.nextFailed,
    nextCanLoad: widget.nextCanLoad,
    onRetryNext: widget.onRetryNext,
    onLoadMoreNext: widget.onLoadMoreNext,
    onPageChanged: widget.onPageChanged,
    itemBuilder: (context, index) {
      final post = widget.sequence!.postAt(index);
      if (post == null) return _entryItem(context, index);
      return _buildPostItem(context, index, details!);
    },
  );

  Widget _wrapPage(
    BuildContext context,
    int index,
    Widget child,
    PostDetailsData<Post>? details,
  ) {
    final entry = widget.sequence?.entries[index];
    final mediaGroup = entry is GroupViewerEntry && _hasMediaPager(index);

    Widget buildPage({bool includePrepared = false}) {
      final post = widget.sequence == null
          ? details?.posts.elementAtOrNull(index)
          : widget.sequence!.postAt(index) ??
                _mediaPostAt(index, includePrepared: includePrepared);
      if (post == null && !mediaGroup) return child;

      Widget wrap(BuildContext context, PostPagePresentation? presentation) {
        final ui = presentation == null
            ? mediaGroup
                  ? _groupSummaryUiBuilder
                  : null
            : presentation.usesGenericPresentation
            ? widget.fallbackUiBuilderDecorator?.call(
                    _genericPostDetailsUiBuilder,
                    post!,
                  ) ??
                  _genericPostDetailsUiBuilder
            : presentation.context.presentation.detailsBuilder(post!);
        Widget result = PostDetailsPageConfiguration(
          uiBuilder: ui,
          layout: presentation?.effectiveConfig.layout,
          // Default Post statistics require an InheritedPost. An unresolved
          // Work has only Group metadata, even when a neighbor already has
          // a fully resolved Post presentation.
          preferredParts: mediaGroup && post == null
              ? _groupSummaryDetailsParts
              : null,
          child: child,
        );
        if (mediaGroup) {
          result = PostDetails(
            data: post == null
                ? null
                : _mediaDetails(
                    index,
                    post,
                    selected: index == _mediaPager?.page,
                  ),
            child: GroupViewerScope(
              entry: entry,
              child: MediaGroupActions(entry: entry, child: result),
            ),
          );
          result = NavigationActivity(
            active:
                PostDetailsPageViewScope.of(context).page == index &&
                NavigationActivity.of(context),
            child: result,
          );
        }
        return result;
      }

      return PostPagePresentationScope(
        post: post,
        sourceBinding: entry?.source,
        fallbackConfig: widget.fallbackConfig,
        groupBuilder: (context) => wrap(context, null),
        builder: (context, ref, presentation) => wrap(context, presentation),
      );
    }

    if (!mediaGroup) return buildPage();
    final groupEntry = entry as GroupViewerEntry;
    // The media-pager itself observes the manifest, but its surrounding
    // Details wrapper otherwise keeps the null Post from the first build.
    // Observe only pages whose media is already eligible for preparation.
    return Consumer(
      builder: (context, ref, _) {
        final pager = PostDetailsPageViewScope.of(context);
        final automaticLoading = ref.watch(
          automaticMediaLoadingEnabledProvider,
        );
        final canPrepare =
            pager.page == index ||
            _checkpoint(groupEntry).visited ||
            (automaticLoading && (pager.page - index).abs() <= 1);
        if (canPrepare) ref.watch(mediaGroupProvider(groupEntry));
        return buildPage(includePrepared: canPrepare);
      },
    );
  }

  Widget _buildPostItem(
    BuildContext context,
    int index,
    PostDetailsData<Post> details,
  ) {
    final post = widget.sequence?.postAt(index) ?? details.posts[index];
    return PostPagePresentationScope(
      post: post,
      sourceBinding: widget.sequence?.entries[index].source,
      fallbackConfig: widget.fallbackConfig,
      builder: (context, ref, presentation) {
        final config = presentation.effectiveConfig;
        final resolver = ref.watch(mediaUrlResolverProvider(config.auth));
        return PostDetailsItem<Post>(
          index: index,
          post: post,
          posts: details.posts,
          transformController: _transformController,
          isInitPageListenable: _isInitPage,
          authConfig: config.auth,
          viewerConfig: config.viewer,
          gestureConfig: config.postGestures,
          imageCacheManager: null,
          detailsController: details.controller,
          imageUrlBuilder: (post) =>
              resolver.resolveMediaUrl(post, config.viewer),
          mediaAspectRatioBuilder: (post) =>
              resolver.resolveMediaAspectRatio(post, config.viewer),
          videoAspectRatioBuilder: (post) =>
              resolver.resolveVideoAspectRatio(post, config.viewer),
        );
      },
    );
  }

  Widget _buildViewer(
    BuildContext context,
    WidgetRef ref,
    PostDetailsData<Post> details,
    PostPagePresentation currentPresentation, {
    required PostDetailsData<Post>? regularDetails,
  }) {
    final posts = details.posts;
    final controller = details.controller;
    final config = currentPresentation.effectiveConfig;
    final auth = config.auth;
    final viewer = config.viewer;
    final layout = config.layout;
    final gestures = config.postGestures;
    final booruRepo = ref.watch(booruRepoProvider(auth));
    final currentPost = currentPresentation.context.post;
    final currentIndex = controller.currentPage.value;
    final fallbackReason =
        _fallbackReasons[currentIndex] ?? currentPresentation.fallbackReason;
    final recovery = switch ((
      fallbackReason,
      currentPresentation.config,
      widget.postRecoveryBuilder,
      _recovering.contains(currentIndex),
    )) {
      (
        final PostPresentationFallbackReason _,
        final config?,
        final builder?,
        false,
      ) =>
        builder(currentPost, config),
      _ => null,
    };
    final startAutomaticRecovery =
        recovery != null && _automaticRecoveryAttempted.add(currentIndex);
    if (startAutomaticRecovery) {
      // Reserve the attempt before the next frame so rebuilds cannot queue it twice.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _recoverPost(
            details: details,
            index: currentIndex,
            recovery: recovery,
          ),
        );
      });
    }
    final hideWarning =
        startAutomaticRecovery || _recovering.contains(currentIndex);
    final uiBuilder = currentPresentation.usesGenericPresentation
        ? widget.fallbackUiBuilderDecorator?.call(
                _genericPostDetailsUiBuilder,
                currentPost,
              ) ??
              _genericPostDetailsUiBuilder
        : currentPresentation.context.presentation.detailsBuilder(currentPost);

    final scaffold = PostDetailsPageScaffold<Post>(
      key: _viewerScaffoldKey,
      sequence: widget.sequence,
      hasMediaPager: _hasMediaPager,
      mediaNavigationBuilder: _mediaNavigation,
      pagePostBuilder: _mediaPostAt,
      pageIndicatorBuilder: _pageIndicator,
      pageWrapperBuilder: (context, index, child) =>
          _wrapPage(context, index, child, regularDetails),
      transformController: _transformController,
      isInitPage: _isInitPage,
      controller: controller,
      posts: posts,
      nextLoading: widget.nextLoading,
      nextFailed: widget.nextFailed,
      nextCanLoad: widget.nextCanLoad,
      onRetryNext: widget.onRetryNext,
      onLoadMoreNext: widget.onLoadMoreNext,
      onPageChanged: widget.onPageChanged,
      postGestureHandlerBuilder: booruRepo?.handlePostGesture,
      uiBuilder: uiBuilder,
      gestureConfig: gestures,
      layoutConfig: layout,
      viewerWarning: currentPresentation.usesGenericPresentation && !hideWarning
          ? PostPresentationFallbackWarning(
              reason: fallbackReason!,
              onRetry: recovery == null
                  ? null
                  : () => unawaited(
                      _recoverPost(
                        details: details,
                        index: currentIndex,
                        recovery: recovery,
                      ),
                    ),
            )
          : null,
      actions: defaultActions(
        note: currentPresentation.usesGenericPresentation
            ? null
            : NoteActionButtonWithProvider(
                currentPost: controller.currentPost,
                config: auth,
              ),
        fallbackMoreButton: DefaultFallbackBackupMoreButton<Post>(
          layoutConfig: layout,
          controller: controller,
          authConfig: auth,
          viewerConfig: viewer,
        ),
      ),
      itemBuilder: (context, index) {
        if (widget.sequence != null && widget.sequence!.postAt(index) == null) {
          return _entryItem(context, index);
        }
        return _buildPostItem(context, index, regularDetails!);
      },
    );

    final post = currentPost;
    final wrapper =
        currentPresentation.context.presentation.detailsWrapperBuilder;
    final behaviorCompanion = wrapper == null
        ? null
        : wrapper(
            post: post,
            child: const SizedBox.shrink(),
          );

    return CurrentPostDetailsNotes(
      post: post,
      viewerConfig: viewer,
      authConfig: auth,
      enabled: !currentPresentation.usesGenericPresentation,
      child: Stack(
        children: [
          scaffold,
          if (behaviorCompanion != null) Offstage(child: behaviorCompanion),
        ],
      ),
    );
  }

  Future<void> _recoverPost({
    required PostDetailsData<Post> details,
    required int index,
    required PostRecoveryCallback recovery,
  }) async {
    if (!mounted || _recovering.contains(index)) return;
    final binding = widget.sequence?.entries[index].source;
    final startedAccess = binding == null
        ? null
        : ref.read(viewerSourceAccessProvider(binding))?.key;
    if (binding != null && startedAccess == null) return;
    final originalIdentity = postViewerIdentity(
      details.controller.postAtPage(index)!,
    );
    setState(() => _recovering.add(index));
    late final PostRecoveryResult result;
    try {
      result = await recovery();
    } catch (_) {
      result = const PostRecoveryFailure(
        PostPresentationFallbackReason.refreshFailed,
      );
    }
    if (!mounted) return;
    if (details.controller.postAtPage(index) == null ||
        postViewerIdentity(details.controller.postAtPage(index)!) !=
            originalIdentity) {
      setState(() => _recovering.remove(index));
      return;
    }

    if (binding != null &&
        ref.read(viewerSourceAccessProvider(binding))?.key != startedAccess) {
      setState(() {
        _recovering.remove(index);
        _fallbackReasons[index] = PostPresentationFallbackReason.missingProfile;
      });
      return;
    }
    switch (result) {
      case PostRecoverySuccess(:final post):
        details.controller.replacePost(index, post);
        setState(() {
          _fallbackReasons.remove(index);
          _recovering.remove(index);
        });
      case PostRecoveryFailure(:final reason):
        setState(() {
          _fallbackReasons[index] = reason;
          _recovering.remove(index);
        });
    }
  }
}

// Group metadata can render before its first Page is resolved. Do not wait
// for a synthetic Post or for the Page manifest before presenting Details.
const _groupSummaryDetailsParts = {
  DetailsPart.artistInfo,
  DetailsPart.tags,
};

final _groupSummaryUiBuilder = PostDetailsUIBuilder(
  full: {
    DetailsPart.artistInfo: (context) => const _GroupSummaryInformation(),
    DetailsPart.tags: (context) => const _GroupSummaryTags(),
  },
);

class _GroupSummaryInformation extends ConsumerWidget {
  const _GroupSummaryInformation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    if (entry == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final state = ref.watch(mediaGroupProvider(entry));
    if (state.access == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final details = state.details;
    final title = details?.summary.title ?? entry.summary.title ?? '';
    final description = details?.description?.text ?? '';
    final creators = details?.creators ?? const [];
    return SliverToBoxAdapter(
      child: ArtistSection(
        commentary: ArtistCommentary(
          originalTitle: title,
          originalDescription: description,
          translatedTitle: '',
          translatedDescription: '',
        ),
        artistTags: {for (final creator in creators) creator.displayName},
        source:
            InheritedPost.maybeOf<Post>(context)?.source ?? PostSource.none(),
      ),
    );
  }
}

class _GroupSummaryTags extends ConsumerWidget {
  const _GroupSummaryTags();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    if (entry == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final state = ref.watch(mediaGroupProvider(entry));
    if (state.access == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final tags =
        state.details?.tags ??
        state.details?.summary.previewTags ??
        entry.summary.previewTags;
    if (tags == null || tags.values.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: RawTagsTile(
        title: Text(context.t.tags.counter(n: tags.values.length)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags.values)
                  if ((tag.displayName ?? tag.name) case final name?
                      when name.isNotEmpty)
                    KurumiCompactChip(label: name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _genericPostDetailsUiBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(showSource: true),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(showSource: true),
    DetailsPart.tags: (context) => const _GenericPostTagsSection(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(),
  },
);

class _GenericPostTagsSection extends StatelessWidget {
  const _GenericPostTagsSection();

  @override
  Widget build(BuildContext context) {
    final post = InheritedPost.of(context);
    final tags = post.tags.toList()..sort();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t.post.detail.widgets.tags,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  Chip(label: Text(tag.replaceAll('_', ' '))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostPresentationFallbackWarning extends StatelessWidget {
  const PostPresentationFallbackWarning({
    required this.reason,
    this.onRetry,
    super.key,
  });

  final PostPresentationFallbackReason reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      PostPresentationFallbackReason.missingProfile =>
        context.t.post.detail.fallback.missing_profile,
      PostPresentationFallbackReason.ambiguousProfile =>
        context.t.post.detail.fallback.ambiguous_profile,
      PostPresentationFallbackReason.unavailableEngine =>
        context.t.post.detail.fallback.unavailable_engine,
      PostPresentationFallbackReason.malformedData =>
        context.t.post.detail.fallback.malformed_data,
      PostPresentationFallbackReason.unsupportedVersion =>
        context.t.post.detail.fallback.unsupported_version,
      PostPresentationFallbackReason.removedUpstreamPost =>
        context.t.post.detail.fallback.removed_upstream_post,
      PostPresentationFallbackReason.refreshFailed =>
        context.t.post.detail.fallback.refresh_failed,
      PostPresentationFallbackReason.incompatiblePresentation =>
        context.t.post.detail.site_features_unavailable,
    };

    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Material(
        color: Kurumi.themeOf(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.warning, fill: 1),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
