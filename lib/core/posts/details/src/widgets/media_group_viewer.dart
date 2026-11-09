import 'dart:async';

import '../../../../../foundation/loggers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../../../../bookmarks/src/providers/bookmark_provider.dart';
import '../../../../bookmarks/src/types/content_group_bookmark.dart';
import '../../../../bookmarks/src/types/stored_group_snapshot.dart';
import '../../../../bookmarks/src/widgets/bookmark_group_picker.dart';
import '../../../../configs/config/types.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../content/content_media_access.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/types.dart';
import '../../../../downloads/downloader/providers.dart';
import '../../../../images/providers.dart';
import '../../../../navigation/destination_activity.dart';
import '../../../../settings/providers.dart';
import '../../../details_pageview/widgets.dart';
import '../../../links/share_group_link_button.dart';
import '../../../post/types.dart';
import '../../../shares/src/providers.dart';
import '../types/post_details.dart';
import '../types/post_viewer_transformation_controller.dart';
import 'post_viewer_transformation_scope.dart';
import 'post_viewer_auto_comic_strip.dart';
import '../providers/providers.dart';
import '../../../media_preload/providers.dart';
import '../../../media_preload/types.dart';
import '../../../media_preload/src/viewer_preload_metadata.dart';
import '../../../listing/providers.dart';
import '../../../../settings/types.dart';

import 'package:html/parser.dart' as html;

import 'group_viewer_scope.dart';
import 'native_metadata_selection.dart';
import 'post_details_controller.dart';
import 'post_details_item.dart';
import 'post_details_page_view_scope.dart';

/// Shared native Work/Gallery composition inside the existing outer viewer.
/// Only the image region owns a Page pager; metadata remains in the outer
/// occurrence so horizontal details swipes continue to navigate Works.
class MediaGroupViewer extends ConsumerWidget {
  const MediaGroupViewer({required this.details, super.key});
  final ContentGroupDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessKey = ref.watch(currentContentAccessKeyProvider);
    final access = accessKey == null
        ? null
        : ref.watch(contentAccessContextProvider(accessKey));
    if (access == null)
      return Center(child: Text(context.t.bookmark.pool_unavailable));
    final key = GroupLoadKey(
      reference: details.summary.reference,
      access: access.key,
    );
    final value = ref.watch(groupMembersProvider(key));
    // Loading/revocation removes all previous Page actions immediately.
    if (value.isLoading || value.hasError || value.valueOrNull == null) {
      return _MediaGroupLoaded(
        key: ValueKey((
          GroupViewerScope.maybeEntryOf(context)?.occurrenceId,
          'no-media',
          value.hasError,
        )),
        details: details,
        access: access,
        loadKey: key,
        members: GroupMembersState(
          members: const [],
          resolved: const {},
          generation: -1,
        ),
        pending: value.isLoading,
        failed: value.hasError,
      );
    }
    final members = value.requireValue;
    return _MediaGroupLoaded(
      key: ValueKey((
        GroupViewerScope.maybeEntryOf(context)?.occurrenceId,
        members.generation,
      )),
      details: details,
      access: access,
      loadKey: key,
      members: members,
    );
  }
}

class _MediaGroupLoaded extends ConsumerStatefulWidget {
  const _MediaGroupLoaded({
    required this.details,
    required this.access,
    required this.loadKey,
    required this.members,
    this.pending = false,
    this.failed = false,
    super.key,
  });
  final ContentGroupDetails details;
  final ContentAccessContext access;
  final GroupLoadKey loadKey;
  final GroupMembersState members;
  final bool pending;
  final bool failed;
  @override
  ConsumerState<_MediaGroupLoaded> createState() => _MediaGroupLoadedState();
}

class _NativeReadingCheckpoint {
  _NativeReadingCheckpoint({
    required this.memberKey,
    required this.index,
    required this.overview,
    required Map<String, Matrix4> transforms,
  }) : transforms = Map.unmodifiable(transforms);
  final String? memberKey;
  final int index;
  final bool overview;
  final Map<String, Matrix4> transforms;
}

class _MediaGroupLoadedState extends ConsumerState<_MediaGroupLoaded> {
  late int _index;
  var _overview = false;
  var _downloading = false;
  var _cancelDownloads = false;
  var _queued = 0;
  var _downloadTotal = 0;
  var _missing = 0;
  var _incomplete = false;
  var _zoomed = false;
  final _alwaysVisible = ValueNotifier(true);
  var _initialized = false;
  PreloadManager? _preloader;
  final _directions = DirectionHistory();
  var _preloadScheduled = false;
  final _transforms = <String, Matrix4>{};
  late PageController _pages;
  PageStorageBucket? _storage;
  late Object _storageKey;
  String? _restoreMemberKey;
  int? _restoreIndex;
  var _restoring = false;
  var _restoreFailed = false;
  var _restoreScheduled = false;
  Object get _checkpoint => (
    'native-media',
    GroupViewerScope.maybeEntryOf(context)?.occurrenceId ??
        widget.details.summary.reference,
  );

  @override
  void initState() {
    super.initState();
    _index = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _storage = PageStorage.maybeOf(context);
    _storageKey = _checkpoint;
    final checkpoint = _storage?.readState(context, identifier: _storageKey);
    if (checkpoint is _NativeReadingCheckpoint) {
      _restoreMemberKey = checkpoint.memberKey;
      _restoreIndex = checkpoint.index;
      _overview = checkpoint.overview;
      _transforms.addAll(checkpoint.transforms);
    } else if (checkpoint is (int, bool)) {
      _restoreIndex = checkpoint.$1;
      _overview = checkpoint.$2;
    } else {
      _restoreMemberKey = GroupViewerScope.maybeEntryOf(context)
          ?.initialMemberKey;
    }
    final selected = _restoredIndex(widget.members);
    if (selected != null) {
      _index = selected;
    } else if (_restoreMemberKey != null || _restoreIndex != null) {
      // A saved later Page must never silently become the last Page in batch1.
      _restoring = true;
    }
    _pages = PageController(initialPage: _index);
  }

  int? _restoredIndex(GroupMembersState state) {
    if (_restoreMemberKey case final key?) {
      final index = state.members.indexWhere(
        (member) => member.memberKey == key,
      );
      return index >= 0 ? index : null;
    }
    if (_restoreIndex case final index?) {
      return index >= 0 && index < state.members.length ? index : null;
    }
    return 0;
  }

  void _saveCheckpoint() {
    if (!mounted ||
        !_initialized ||
        _restoring ||
        _restoreFailed ||
        widget.members.members.isEmpty)
      return;
    _storage?.writeState(
      context,
      _NativeReadingCheckpoint(
        memberKey: widget.members.members.elementAtOrNull(_index)?.memberKey,
        index: _index,
        overview: _overview,
        transforms: _transforms,
      ),
      identifier: _storageKey,
    );
  }

  void _scheduleRestore() {
    if (!_restoring ||
        _restoreScheduled ||
        widget.pending ||
        widget.failed ||
        !_current())
      return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!_current()) return;
        var state =
            ref.read(groupMembersProvider(widget.loadKey)).valueOrNull ??
            widget.members;
        var selected = _restoredIndex(state);
        var batches = 0;
        while (selected == null &&
            state.next != null &&
            state.nextPageError == null &&
            state.members.length < 5000 &&
            batches++ < 128 &&
            _current()) {
          await ref
              .read(groupMembersProvider(widget.loadKey).notifier)
              .loadNext();
          if (!_current()) return;
          final next = ref
              .read(groupMembersProvider(widget.loadKey))
              .valueOrNull;
          if (next == null || next.members.length <= state.members.length)
            break;
          state = next;
          selected = _restoredIndex(state);
        }
        if (!_current()) return;
        if (selected == null) {
          setState(() {
            _restoring = false;
            _restoreFailed = true;
          });
          return;
        }
        // The placeholder never attached this controller. Publish the requested
        // Page only after the source manifest has supplied its stable slot.
        _pages.dispose();
        _pages = PageController(initialPage: selected);
        setState(() {
          _index = selected!;
          _restoring = false;
        });
      } catch (error, stack) {
        if (!mounted) return;
        ref
            .read(loggerProvider)
            .handledError(
              'Media',
              'native_page_restore',
              error: error,
              stackTrace: stack,
              outcome: 'page_unavailable',
            );
        setState(() {
          _restoring = false;
          _restoreFailed = true;
        });
      } finally {
        _restoreScheduled = false;
      }
    });
  }

  @override
  void dispose() {
    _preloader?.cancelAll();
    _cancelDownloads = true;
    _pages.dispose();
    _alwaysVisible.dispose();
    super.dispose();
  }

  bool _current() =>
      mounted &&
      NavigationActivity.of(context) &&
      identical(
        ref.read(contentAccessContextProvider(widget.access.key)),
        widget.access,
      );
  Post? _postAt(int index) {
    if (_restoring || _restoreFailed || widget.pending || widget.failed)
      return null;
    final member = widget.members.members.elementAtOrNull(index);
    if (member == null || member.availability != MemberAvailability.available)
      return null;
    return switch (widget.members.resolved[member.reference.identity]) {
      PostContentEntry(:final post) => post,
      _ => null,
    };
  }

  void _select(int index) {
    _directions.addDirection(index, _index);
    setState(() {
      _index = index;
      _zoomed = false;
    });
    _saveCheckpoint();
    if (index >= widget.members.members.length - 2 &&
        widget.members.next != null &&
        widget.members.nextPageError == null &&
        _current())
      unawaited(
        ref.read(groupMembersProvider(widget.loadKey).notifier).loadNext(),
      );
  }

  void _schedulePreload() {
    if (_preloadScheduled || _restoring || _restoreFailed) return;
    _preloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScheduled = false;
      if (!_current()) {
        _preloader?.cancelAll();
        return;
      }
      final config = widget.access.config!;
      final resolver = ref.read(mediaUrlResolverProvider(config.auth));
      final thumbnail = ref.read(
        gridThumbnailUrlGeneratorProvider(config.auth),
      );
      final settings = ref.read(gridThumbnailSettingsProvider(config.auth));
      _preloader?.preloadWithStrategy(
        strategy: DirectionBasedPreloadStrategy(directionHistory: _directions),
        currentPage: _index,
        itemCount: widget.members.members.length,
        mediaBuilder: (index) {
          final post = _postAt(index);
          if (post == null) return null;
          final display = resolver.resolveMediaUrl(post, config.viewer);
          return thumbnailOnlyViewerPreloadMedia(
            post,
            thumbnailUrl: thumbnail.resolve(post, settings: settings).url,
            displayUrl: display == post.originalImageUrl
                ? ref.read(postQualityProvider(config.auth)) ==
                          PostQuality.original
                      ? post.sampleImageUrl
                      : null
                : display,
          );
        },
      );
    });
  }

  ContentGroupBookmark _draft() {
    final now = DateTime.now().toUtc();
    final tags = widget.details.tags ?? widget.details.summary.previewTags;
    return ContentGroupBookmark(
      id: 0,
      createdAt: now,
      observedAt: now,
      sourceProfileHint: widget.access.key.profileId,
      snapshot: StoredGroupSnapshot(
        summary: widget.details.summary,
        details: widget.details,
        index: tags == null
            ? null
            : GroupBookmarkIndex(
                tags: {
                  for (final tag in tags.values)
                    if (tag.name case final name?) name,
                },
                basis: GroupTagIndexBasis.sourceGroup,
                coverage: tags.coverage,
              ),
      ),
    );
  }

  Future<void> _bookmark({bool page = false}) async {
    if (!_current()) return;
    final config = widget.access.config!;
    final post = _postAt(_index);
    final request = page
        ? post == null
              ? null
              : PostBookmarkPickerRequest(
                  config: config.auth,
                  post: post,
                  source: config,
                )
        : ContentGroupBookmarkPickerRequest(
            draft: _draft(),
            source: config,
            access: widget.access.key,
          );
    if (request != null)
      await showBookmarkPickerDialog(context, request: request);
  }

  Future<void> _chooseBookmark() async {
    if (!_current()) return;
    final config = widget.access.config!;
    final post = _postAt(_index);
    final work = ContentGroupBookmarkPickerRequest(
      draft: _draft(),
      source: config,
      access: widget.access.key,
    );
    final page = post == null
        ? null
        : PostBookmarkPickerRequest(
            config: config.auth,
            post: post,
            source: config,
          );
    final selected = await showDialog<BookmarkPickerRequest>(
      context: context,
      builder: (context) => KurumiDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KurumiPopupMenuItem(
              title: Text(context.t.content_viewer.bookmark_group),
              icon: const Icon(Icons.bookmarks_outlined),
              onTap: () => Navigator.pop(context, work),
            ),
            if (page != null)
              KurumiPopupMenuItem(
                title: Text(context.t.content_viewer.bookmark_page),
                icon: const Icon(Icons.bookmark_outline),
                onTap: () => Navigator.pop(context, page),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || !_current()) return;
    await showBookmarkPickerDialog(context, request: selected);
  }

  Future<bool> _download(Post post) async {
    final config = widget.access.config!;
    if (!_current() || config.anonymousReadScope != null) return false;
    final params = ref.read(
      sourceDownloadNotifierParamsProvider((config.auth, config.download)),
    );
    final logger = ref.read(loggerProvider);
    try {
      return await ref
              .read(downloadNotifierProvider(params).notifier)
              .download(post, isCurrent: _current) !=
          null;
    } catch (error, stack) {
      logger.handledError(
        'Media',
        'native_page_download',
        error: error,
        stackTrace: stack,
        outcome: 'not_queued',
      );
      return false;
    }
  }

  Future<void> _downloadAll() async {
    if (_downloading ||
        !_current() ||
        widget.access.config!.anonymousReadScope != null)
      return;
    setState(() {
      _downloading = true;
      _cancelDownloads = false;
      _queued = 0;
      _downloadTotal = 0;
      _missing = 0;
      _incomplete = false;
    });
    try {
      var state = widget.members;
      // Bound manifest preparation. No missing Page is represented as a queued file.
      while (state.next != null &&
          state.members.length < 5000 &&
          !_cancelDownloads &&
          _current()) {
        await ref
            .read(groupMembersProvider(widget.loadKey).notifier)
            .loadNext();
        final next = ref.read(groupMembersProvider(widget.loadKey)).valueOrNull;
        if (next == null ||
            next.nextPageError != null ||
            next.members.length == state.members.length)
          break;
        state = next;
      }
      if (!_current() || _cancelDownloads) return;
      final boundedMembers = state.members.take(5000).toList();
      final captured = [
        for (final member in boundedMembers)
          if (member.availability == MemberAvailability.available)
            if (state.resolved[member.reference.identity] case PostContentEntry(
              :final post,
            ))
              post,
      ];
      setState(() {
        _downloadTotal = captured.length;
        _missing = boundedMembers.length - captured.length;
        _incomplete =
            state.next != null ||
            state.nextPageError != null ||
            state.members.length > boundedMembers.length;
      });
      for (final post in captured) {
        if (_cancelDownloads || !_current()) break;
        if (await _download(post)) {
          if (mounted) setState(() => _queued++);
        } else {
          if (mounted) setState(() => _missing++);
        }
      }
    } catch (error, stack) {
      ref
          .read(loggerProvider)
          .handledError(
            'Media',
            'native_download_all',
            error: error,
            stackTrace: stack,
            outcome: 'incomplete',
          );
      if (mounted) setState(() => _incomplete = true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _share(Post post) {
    if (!_current()) return;
    final config = widget.access.config!;
    ref
        .read(shareProvider)
        .sharePost(
          post,
          config.auth,
          context: context,
          configViewer: config.viewer,
          download: config.download,
          filenameBuilder: null,
          imageCacheManager: ref.read(defaultImageCacheManagerProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final outer = PostDetailsPageViewScope.maybeOf(context);
    return ValueListenableBuilder(
      valueListenable: outer?.overlay ?? _alwaysVisible,
      builder: (context, controlsVisible, _) =>
          _buildContent(context, controlsVisible, outer),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool controlsVisible,
    PostDetailsPageViewController? outer,
  ) {
    final config = widget.access.config!;
    _scheduleRestore();
    if (NavigationActivity.of(context)) {
      _preloader = ref.watch(
        contentOccurrencePreloadManagerProvider((
          source: (auth: config.auth, access: widget.access.key),
          occurrence: this,
        )),
      );
      _schedulePreload();
    } else {
      _preloader?.cancelAll();
    }
    final members = widget.members.members;
    final post = _postAt(_index);
    final strings = context.t.content_viewer;
    final entry = GroupViewerScope.maybeEntryOf(context);
    final saved =
        ref
            .watch(bookmarkProvider)
            .valueOrNull
            ?.idByContent
            .containsKey(widget.details.summary.reference.identity) ??
        false;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (controlsVisible)
            Row(
              children: [
                IconButton(
                  tooltip: context.t.generic.action.back,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    widget.details.summary.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: _overview ? strings.image_view : strings.overview,
                  icon: Icon(
                    _overview ? Icons.image_outlined : Icons.grid_view,
                  ),
                  onPressed: () {
                    setState(() => _overview = !_overview);
                    _saveCheckpoint();
                  },
                ),
              ],
            ),
          Expanded(
            flex: _overview ? 1 : 3,
            child: widget.pending || _restoring
                ? const Center(child: CircularProgressIndicator())
                : widget.failed || _restoreFailed
                ? Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.invalidate(groupMembersProvider(widget.loadKey)),
                      child: Text(context.t.generic.action.retry),
                    ),
                  )
                : PageView.builder(
                    controller: _pages,
                    itemCount: members.length,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                    onPageChanged: _select,
                    itemBuilder: (context, index) {
                      final page = _postAt(index);
                      if (page == null)
                        return Center(child: Text(strings.page_unavailable));
                      final memberKey = members[index].memberKey;
                      void go(int target) {
                        if (_pages.hasClients) _pages.jumpToPage(target);
                      }

                      return ZoomPageNavigationScope(
                        previousLabel: context.t.infinite_scroll.previous_page,
                        nextLabel: context.t.infinite_scroll.next_page,
                        previousActionId: index > 0
                            ? members[index - 1].memberKey
                            : null,
                        nextActionId: index + 1 < members.length
                            ? members[index + 1].memberKey
                            : null,
                        onPrevious: index > 0 ? () => go(index - 1) : null,
                        onNext: index + 1 < members.length
                            ? () => go(index + 1)
                            : null,
                        child: _NativePageMedia(
                          key: ValueKey((entry?.occurrenceId, memberKey)),
                          post: page,
                          config: config,
                          active:
                              index == _index && NavigationActivity.of(context),
                          initialTransform: _transforms[memberKey],
                          onOverlay: () => outer?.toggleOverlay(),
                          onZoom: (zoomed) {
                            if (mounted && index == _index && _zoomed != zoomed)
                              setState(() => _zoomed = zoomed);
                          },
                          onCheckpoint: (matrix) {
                            _transforms.remove(memberKey);
                            if (_transforms.length >= 16)
                              _transforms.remove(_transforms.keys.first);
                            _transforms[memberKey] = matrix;
                            _saveCheckpoint();
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (controlsVisible && !_restoring && !_restoreFailed)
            Text(
              '${members.isEmpty
                  ? 0
                  : members.elementAtOrNull(_index)?.sourcePosition == null
                  ? _index + 1
                  : (members[_index].sourcePosition ?? _index) + 1} / ${widget.members.sourceTotal ?? members.length}',
            ),
          if (widget.members.nextPageError != null)
            TextButton(
              onPressed: () => ref
                  .read(groupMembersProvider(widget.loadKey).notifier)
                  .retryNext(),
              child: Text(context.t.generic.action.retry),
            ),
          if (controlsVisible)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TooltipTheme(
                  // The tooltip must not consume the alternate-action hold.
                  data: TooltipTheme.of(context)
                      .copyWith(triggerMode: TooltipTriggerMode.manual),
                  child: GestureDetector(
                    onLongPress: _chooseBookmark,
                    child: IconButton(
                      tooltip: strings.bookmark_group,
                      icon: Stack(
                        children: [
                          Icon(
                            saved ? Icons.bookmarks : Icons.bookmarks_outlined,
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(Icons.arrow_drop_down, size: 10),
                          ),
                        ],
                      ),
                      onPressed: _current() ? _bookmark : null,
                    ),
                  ),
                ),

                TooltipTheme(
                  data: TooltipTheme.of(context)
                      .copyWith(triggerMode: TooltipTriggerMode.manual),
                  child: GestureDetector(
                    onLongPress: _downloadAll,
                    child: IconButton(
                      tooltip: strings.download_page,
                      icon: const Icon(Icons.download),
                      onPressed:
                          post == null || config.anonymousReadScope != null
                          ? null
                          : () => _download(post),
                    ),
                  ),
                ),
                if (_downloading)
                  IconButton(
                    tooltip: context.t.generic.action.cancel,
                    onPressed: () => setState(() => _cancelDownloads = true),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                KurumiPopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  semanticLabel: context.t.generic.action.more,
                  items: [
                    KurumiPopupMenuItem(
                      title: Text(strings.bookmark_group),
                      icon: const Icon(Icons.bookmarks_outlined),
                      onTap: _bookmark,
                    ),
                    KurumiPopupMenuItem(
                      title: Text(strings.bookmark_page),
                      icon: const Icon(Icons.bookmark_outline),
                      onTap: post == null ? null : () => _bookmark(page: true),
                    ),
                    KurumiPopupMenuItem(
                      title: Text(strings.download_all),
                      icon: const Icon(Icons.download_for_offline_outlined),
                      onTap: _downloading || config.anonymousReadScope != null
                          ? null
                          : _downloadAll,
                    ),
                  ],
                ),
                IconButton(
                  tooltip: context.t.post.action.share,
                  onPressed: post == null ? null : () => _share(post),
                  icon: const Icon(Icons.ios_share),
                ),
                const GroupLinkShareButton(),
              ],
            ),
          if (_downloading || _downloadTotal > 0)
            Text(
              strings.download_progress(queued: _queued, total: _downloadTotal),
            ),
          if (_missing > 0) Text('${strings.page_unavailable}: $_missing'),
          if (_incomplete) Text(strings.download_incomplete),
          Expanded(
            flex: _overview ? 3 : 1,
            child: SingleChildScrollView(
              key: PageStorageKey((_checkpoint, 'details')),
              padding: const EdgeInsets.all(12),
              child: NativeMetadataText(
                [
                  widget.details.summary.title ?? '',
                  if (widget.details.description case final description?)
                    description.format == GroupTextFormat.html
                        ? html.parseFragment(description.text).text ?? ''
                        : description.text,
                  if (widget.details.creators case final creators?)
                    creators.map((creator) => creator.displayName).join(', '),
                  if (widget.details.tags case final tags?)
                    tags.values
                        .map((tag) => tag.displayName ?? tag.name ?? '')
                        .join(' '),
                ].where((value) => value.isNotEmpty).join('\n\n'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reuses existing Post media, zoom geometry, progressive quality and gestures
/// with a Page-local controller. It owns no route, app bar or Back handler.
class _NativePageMedia extends ConsumerStatefulWidget {
  const _NativePageMedia({
    required this.post,
    required this.config,
    required this.active,
    required this.onZoom,
    required this.onCheckpoint,
    required this.onOverlay,
    this.initialTransform,
    super.key,
  });
  final Post post;
  final BooruConfig config;
  final bool active;
  final VoidCallback onOverlay;
  final ValueChanged<bool> onZoom;
  final ValueChanged<Matrix4> onCheckpoint;
  final Matrix4? initialTransform;
  @override
  ConsumerState<_NativePageMedia> createState() => _NativePageMediaState();
}

class _NativePageMediaState extends ConsumerState<_NativePageMedia> {
  late final _transform = TransformationController(
    widget.initialTransform?.clone(),
  );
  late final _viewerTransform = PostViewerTransformationController(_transform);
  final _initial = ValueNotifier(true);
  late final PostDetailsController<Post> _details;
  late final PostDetailsPageViewController _media;
  @override
  void initState() {
    super.initState();
    _details = PostDetailsController(
      scrollController: null,
      initialPage: 0,
      posts: [widget.post],
      initialThumbnailUrl: null,
      reduceAnimations: ref.read(settingsProvider).reduceAnimations,
      dislclaimer: null,
      doubleTapSeekDuration: ref
          .read(imageViewerSettingsProvider)
          .doubleTapSeekDuration,
    );
    _media = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    _details.setNavigationActive(widget.active);
    _transform.addListener(_checkpointTransform);
    _media.zoom.addListener(_onZoom);
    _media.overlay.addListener(widget.onOverlay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _details.onPageSettled(0);
    });
  }

  void _checkpointTransform() => widget.onCheckpoint(_transform.value.clone());

  void _onZoom() {
    if (mounted && widget.active) widget.onZoom(_media.zoom.value);
  }

  @override
  void didUpdateWidget(_NativePageMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    _media.overlay.removeListener(oldWidget.onOverlay);
    _media.overlay.addListener(widget.onOverlay);
    _details.setNavigationActive(widget.active);
  }

  @override
  void dispose() {
    _transform.removeListener(_checkpointTransform);
    _media.zoom.removeListener(_onZoom);
    _media.overlay.removeListener(widget.onOverlay);
    _details.dispose();
    _media.dispose();
    _transform.dispose();
    _initial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolver = ref.watch(mediaUrlResolverProvider(widget.config.auth));
    return HeroMode(
      enabled: false,
      child: PostViewerTransformationScope(
        controller: _viewerTransform,
        child: PostViewerTransformationViewport(
          child: PostViewerAutoComicStrip(
            index: 0,
            postId: widget.post.id,
            contentSize: Size(widget.post.width, widget.post.height),
            currentSettledPage: _details.currentSettledPage,
            enabled:
                widget.initialTransform == null &&
                ref.watch(imageViewerSettingsProvider).autoAdjustComicStrips &&
                !widget.post.isVideo,
            child: PostDetails(
              data: PostDetailsData<Post>(
                posts: [widget.post],
                controller: _details,
              ),
              child: PostDetailsPageViewScope(
                controller: _media,
                child: PostDetailsItem<Post>(
                  index: 0,
                  posts: [widget.post],
                  transformController: _transform,
                  isInitPageListenable: _initial,
                  imageCacheManager: ref.watch(
                    defaultImageCacheManagerProvider,
                  ),
                  detailsController: _details,
                  authConfig: widget.config.auth,
                  viewerConfig: widget.config.viewer,
                  gestureConfig: widget.config.postGestures,
                  imageUrlBuilder: (post) =>
                      resolver.resolveMediaUrl(post, widget.config.viewer),
                  mediaAspectRatioBuilder: (post) => resolver
                      .resolveMediaAspectRatio(post, widget.config.viewer),
                  videoAspectRatioBuilder: (post) => resolver
                      .resolveVideoAspectRatio(post, widget.config.viewer),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
