import 'native_metadata_selection.dart';

import 'package:foundation/performance.dart';

import '../../../../../foundation/performance/performance_navigation.dart';

// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../notes/note/widgets.dart';
import '../../../details_parts/types.dart';
import '../../../details_parts/widgets.dart';
import '../../../post/types.dart';
import '../providers/providers.dart';
import '../providers/viewer_source_access_provider.dart';
import '../routes/post_details_live_source.dart';
import '../types/inherited_post.dart';
import '../types/post_details.dart';
import '../types/viewer_entry.dart';
import 'viewer_entry_content.dart';
import 'post_details_page_view_scope.dart';
import 'post_details_actions.dart';
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
  final _transformController = TransformationController();
  final _isInitPage = ValueNotifier(true);
  final _fallbackReasons = <int, PostPresentationFallbackReason>{};
  final _recovering = <int>{};
  final _automaticRecoveryAttempted = <int>{};

  @override
  void dispose() {
    _transformController.dispose();
    _isInitPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = PostDetails.maybeOf<Post>(context);
    final pager = PostDetailsPageViewScope.of(context);
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
                : sequence.postAt(pager.page);
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
              builder: (context, ref, presentation) =>
                  _buildViewer(context, ref, details!, presentation),
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
    sequence: widget.sequence,
    controller: details?.controller,
    posts: details?.posts ?? const [],
    transformController: _transformController,
    isInitPage: _isInitPage,
    gestureConfig: null,
    layoutConfig: null,
    postGestureHandlerBuilder: null,
    uiBuilder: null,
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
    PostPagePresentation currentPresentation,
  ) {
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
      sequence: widget.sequence,
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
        return _buildPostItem(context, index, details);
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
