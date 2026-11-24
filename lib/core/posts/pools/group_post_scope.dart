import 'dart:async';

import '../../http/client/coordination.dart';
import '../../content/groups/prepared_group_reads.dart';

import 'package:flutter/foundation.dart' show mapEquals;

import '../../blacklists/providers.dart';
import '../../content/groups/related_group_counts.dart';
import '../../content/groups/group_members_provider.dart';
import '../details/src/widgets/group_viewer_scope.dart';
import '../details/src/providers/group_reading_provider.dart';
import '../details/src/types/group_order_candidate.dart';
import '../listing/src/widgets/post_scope.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../configs/config/providers.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/widgets.dart';
import '../../content/content_access_provider.dart';
import '../../content/content_media_access.dart';
import '../../content/groups/group_source_provider.dart';
import '../../content/types.dart';
import '../../errors/types.dart';
import '../../navigation/destination_activity.dart';
import '../../settings/providers.dart';
import '../listing/types.dart';
import '../listing/widgets.dart';
import '../listing/src/widgets/post_grid_controller.dart';
import '../post/types.dart';
import '../details/src/types/viewer_entry.dart';
import 'src/types/group_post_pager.dart';

/// Keeps the established PostScope/gallery UX while replacing only its source
/// fetcher with the registered, access-bound Group membership contract.
class GroupPostScope extends ConsumerStatefulWidget {
  const GroupPostScope({
    required this.reference,
    required this.perPage,
    required this.builder,
    this.orderKey,
    this.prepareSource,
    this.scrollController,
    super.key,
  });
  final ContentReference reference;
  final String? orderKey;
  final int perPage;
  final void Function(ContentGroupSource source)? prepareSource;
  final ScrollController? scrollController;
  final Widget Function(
    BuildContext context,
    PostGridController<Post> controller,
  )
  builder;
  @override
  ConsumerState<GroupPostScope> createState() => _GroupPostScopeState();
}

class _GroupPostScopeState extends ConsumerState<GroupPostScope> {
  GroupTimelineSession? _session;
  GroupViewerEntry? _readingEntry;
  PrepareGroupTimelineOrder? _prepareTimeline;
  GroupReadingController? _reader;
  Object? _identity;
  PostGridController<Post>? _controller;
  var _projectionRevision = 0;
  ({GroupMetadataKey metadata, int revision})? _ownRefresh;
  var _peerRefreshPending = false;
  var _active = false;
  var _passive = false;
  final _activityChanges = StreamController<void>.broadcast();
  int? _peerInitialPage;

  @override
  void dispose() {
    unawaited(_activityChanges.close());
    if (_reader?.timelinePreparation == _prepareTimeline) {
      _reader?.detachTimeline(_prepareTimeline);
    }
    _session?.dispose();
    super.dispose();
  }

  void _disposeAfterFrame(GroupTimelineSession? session) {
    if (session != null) {
      session.retire();
      WidgetsBinding.instance.addPostFrameCallback((_) => session.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    _active = NavigationActivity.of(context);
    final passive = GroupViewerScope.maybeOf(context)?.passive ?? false;
    if (_passive != passive) {
      _passive = passive;
      _activityChanges.add(null);
      if (!passive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_passive) _session?.publishPreparedPage();
        });
      }
    }
    final config = ref.watchConfig;
    final inherited = ref.watch(currentContentAccessKeyProvider);
    var access = inherited == null
        ? ref.watch(contentProfileAccessProvider(config.id))
        : ref.watch(contentAccessContextProvider(inherited));
    if (access?.config == null ||
        (inherited == null &&
            ViewerSourceBinding(config).resolve([access!.config!]) == null) ||
        (inherited != null && access!.config!.auth != config.auth)) {
      access = null;
    }
    final key = access?.key;
    final source = access == null
        ? null
        : ref.watch(contentGroupSourceStateProvider(access.key)).asData?.value;
    final metadata = key == null
        ? null
        : GroupMetadataKey(reference: widget.reference, access: key);
    if (metadata != null) {
      ref.listen(groupRefreshRevisionProvider(metadata), (previous, next) {
        if (_ownRefresh == (metadata: metadata, revision: next)) return;
        _peerInitialPage = _controller?.pageMode == PageMode.paginated
            ? _controller?.page
            : null;
        // Revoke pending publication immediately, including inactive pages.
        _reader?.cancelOrder();
        _disposeAfterFrame(_session);
        _session = null;
        _identity = null;
        _projectionRevision++;
        _peerRefreshPending = true;
        if (_active) setState(() {});
      });
    }
    if (_peerRefreshPending) {
      if (!_active) return const SizedBox.expand();
      _peerRefreshPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scroll = widget.scrollController;
        if (scroll?.hasClients ?? false) scroll!.jumpTo(0);
      });
    }
    final prepared = key == null
        ? null
        : ref.watch(preparedGroupReadsProvider(key));
    final group = GroupViewerScope.maybeOf(context);
    final readingEntry =
        group?.onOpenMember != null &&
            group?.entry.contentReference == widget.reference &&
            supportsGroupReading(group!.entry)
        ? group.entry
        : null;
    final pageMode = ref.watch(
      imageListingSettingsProvider.select((s) => s.pageMode),
    );
    final shared = group?.onOpenMember != null && pageMode == PageMode.infinite;
    final identity = (
      source,
      key,
      widget.reference,
      widget.orderKey,
      widget.perPage,
      pageMode,
      _projectionRevision,
    );

    GroupTimelineSession createSession(
      String? order, {
      bool preparing = false,
    }) {
      final sharedKey = !shared || key == null
          ? null
          : GroupLoadKey(
              reference: widget.reference,
              access: key,
              orderKey: order,
              requestedLimit: widget.perPage,
            );
      bool accessIsCurrent() {
        if (!mounted || source == null || key == null) return false;
        return identical(
              ref.read(contentGroupSourceStateProvider(key)).asData?.value,
              source,
            ) &&
            (ref
                    .read(contentAccessContextProvider(key))
                    ?.hasSameAuthorization(access!) ??
                false);
      }

      return GroupTimelineSession(
        ref: ref,
        active: !preparing,
        source: source,
        preparedReads: prepared,
        isPassive: () => _passive,
        activityChanges: _activityChanges.stream,
        currentRefreshRevision: () => metadata == null
            ? 0
            : ref.read(groupRefreshRevisionProvider(metadata)),
        config: config,
        reference: widget.reference,
        order: order,
        perPage: widget.perPage,
        pageMode: pageMode,
        sharedKey: sharedKey,
        nextInitialPage: preparing ? null : _peerInitialPage,
        filterSelection: preparing
            ? Map.of(_controller?.activeFilters.value ?? const {})
            : const {},
        accessIsCurrent: accessIsCurrent,
        onRefresh: (invalidated) {
          if (!invalidated || metadata == null || !mounted) return;
          _reader?.cancelOrder();
          _ownRefresh = (
            metadata: metadata,
            revision: ref.read(groupRefreshRevisionProvider(metadata)) + 1,
          );
          ref.read(groupRefreshRevisionProvider(metadata).notifier).advance();
          ref.invalidate(groupDetailsProvider(metadata));
          ref.invalidate(groupSummaryProvider(metadata));
        },
        onConfigurationChanged: () => _reader?.cancelOrder(),
      );
    }

    if (_identity != identity) {
      _reader?.cancelOrder();
      final old = _session;
      _identity = identity;
      if (source != null) widget.prepareSource?.call(source);
      _session = createSession(widget.orderKey);
      _disposeAfterFrame(old);
    }
    final session = _session!;
    _controller = session.controller;
    if (readingEntry != _readingEntry) {
      _reader?.detachTimeline(_prepareTimeline);
      _readingEntry = readingEntry;
      _reader = readingEntry == null
          ? null
          : ref.read(groupReadingProvider(readingEntry).notifier);
    }
    if (_reader case final reader?) {
      _prepareTimeline = (order, cancellation) async {
        final pending = createSession(order, preparing: true);
        final prepared = _PreparedTimeline(
          pending,
          isCurrent: () =>
              mounted &&
              _active &&
              identical(_session, session) &&
              !cancellation.isCancelled,
          canAdoptNow: () =>
              widget.scrollController?.positions.every(
                (position) => !position.isScrollingNotifier.value,
              ) ??
              true,
          onAdopt: () {
            final previous = _session;
            pending.activate();
            _session = pending;
            _identity = (
              source,
              key,
              widget.reference,
              order,
              widget.perPage,
              pageMode,
              _projectionRevision,
            );
            _disposeAfterFrame(previous);
            if (mounted) setState(() {});
          },
        );
        unawaited(cancellation.whenCancel.then((_) => prepared.dispose()));
        try {
          await Future.any([
            pending.controller.prepareInitialPage(
              additionalEmptyPages: shared ? 3 : 0,
            ),
            cancellation.whenCancel,
          ]);
          return prepared;
        } catch (_) {
          prepared.dispose();
          rethrow;
        }
      };
      reader.attachTimeline(_prepareTimeline!);
    }
    final posts = PostScope.borrow<Post>(
      controller: session.controller,
      builder: (context) => KeyedSubtree(
        key: ObjectKey(session),
        child: widget.builder(context, session.controller),
      ),
    );
    return access?.config == null
        ? posts
        : CurrentBooruConfigScope(
            config: access!.config!,
            accessKey: key,
            requireAccess: true,
            child: posts,
          );
  }
}

/// Owns a headless grid and pager for the entire lifetime of a projection.
class GroupTimelineSession {
  GroupTimelineSession({
    required WidgetRef ref,
    required bool active,
    required ContentGroupSource? source,
    required PreparedGroupReads? preparedReads,
    required bool Function() isPassive,
    required Stream<void> activityChanges,
    required int Function() currentRefreshRevision,
    required BooruConfig config,
    required ContentReference reference,
    required String? order,
    required int perPage,
    required PageMode pageMode,
    required GroupLoadKey? sharedKey,
    required int? nextInitialPage,
    required Map<String, bool> filterSelection,
    required bool Function() accessIsCurrent,
    required void Function(bool) onRefresh,
    required VoidCallback onConfigurationChanged,
  }) : _active = active {
    if (source != null) {
      if (sharedKey != null) {
        _retainShared = () {
          _membership ??= ref.listenManual(
            groupMembersProvider(sharedKey),
            (_, _) {},
          );
        };
        if (!isPassive()) _retainShared!();
      }
      _pager = GroupPostPager(
        source: source,
        reference: reference,
        orderKey: order,
        perPage: perPage,
        isCurrent: () => !_retired && !_disposed && accessIsCurrent(),
        isPaginated: () => pageMode == PageMode.paginated,
        relatedCounts: ref.read(relatedGroupCountsProvider.notifier),
        preparedReads: preparedReads,
        isForeground: () => !isPassive(),
        currentRefreshRevision: currentRefreshRevision,
        loadSharedPage: sharedKey == null
            ? null
            : (page) => readSharedGroupPostPage(
                page: page,
                read: () {
                  if (_retired || _disposed || !accessIsCurrent()) {
                    throw RequestCancelledError();
                  }
                  return ref.read(groupMembersProvider(sharedKey).future);
                },
                loadNext: () {
                  if (_retired ||
                      _disposed ||
                      isPassive() ||
                      !accessIsCurrent()) {
                    throw RequestCancelledError();
                  }
                  return ref
                      .read(groupMembersProvider(sharedKey).notifier)
                      .loadNext();
                },
              ),
      );
    }
    Future<PostResult<Post>> fetch(int page) =>
        _pager?.fetch(page) ??
        Future<PostResult<Post>>.error(StateError('Group source unavailable'));

    controller = createScopedPostGridController<Post>(
      read: ref.read,
      filter: () => config.filter,
      pageMode: pageMode,
      mounted: () =>
          !_retired && !_disposed && (source == null || accessIsCurrent()),
      duplicateIdentity: (_) => null,
      initialPage: nextInitialPage,
      initialFilterSelection: filterSelection,
      fetcher: (page) => TaskEither.tryCatch(
        () => isPassive()
            ? runWithApiRequestContext(
                ApiRequestContext(
                  requestClassResolver: () => isPassive()
                      ? ApiRequestClass.preload
                      : ApiRequestClass.interactive,
                  changes: activityChanges,
                  allowCooldownRetry: false,
                ),
                () => fetch(page),
              )
            : fetch(page),
        (error, _) => error is BooruError
            ? error
            : UnknownError(
                error: error,
                message: 'Unable to load Group members',
              ),
      ),
      onRefresh: () {
        if (!isPassive()) onRefresh(_pager?.refresh() ?? false);
      },
      selectionKeysBuilder: _pager?.selectionKeys,
    );
    _blacklist = ref.listenManual(blacklistTagsProvider(config.filter), (
      previous,
      next,
    ) {
      if (!_active || _retired || _disposed || !next.hasValue) return;
      if ((previous?.hasValue ?? false) &&
          previous?.valueOrNull != next.valueOrNull) {
        onConfigurationChanged();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_retired && !_disposed && accessIsCurrent()) {
          unawaited(controller.setBlacklistedTags(next.requireValue));
        }
      });
    });
    var filters = controller.activeFilters.value;
    controller.activeFilters.addListener(() {
      final next = controller.activeFilters.value;
      if (_active && !mapEquals(filters, next)) onConfigurationChanged();
      filters = next;
    });
    if (pageMode == PageMode.paginated) {
      controller.pageNotifier.addListener(() {
        if (_active) onConfigurationChanged();
      });
    }
  }

  GroupPostPager? _pager;
  late final PostGridController<Post> controller;
  ProviderSubscription<AsyncValue<GroupMembersState>>? _membership;
  VoidCallback? _retainShared;
  ProviderSubscription<AsyncValue<Set<String>>>? _blacklist;
  var _disposed = false;
  var _retired = false;
  bool _active;

  void activate() => _active = true;

  void publishPreparedPage() {
    if (_retired || _disposed) return;
    _retainShared?.call();
    _pager?.activate();
  }

  void retire() {
    _retired = true;
    _active = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _blacklist?.close();
    _membership?.close();
    _pager?.dispose();
    controller.dispose();
  }
}

class _PreparedTimeline implements GroupOrderCandidate {
  _PreparedTimeline(
    this.session, {
    required this.isCurrent,
    required this.canAdoptNow,
    required this.onAdopt,
  });
  final GroupTimelineSession session;
  final bool Function() isCurrent;
  final bool Function() canAdoptNow;

  @override
  bool get canAdopt => canAdoptNow();
  final VoidCallback onAdopt;
  var _adopted = false;

  @override
  bool get isReady =>
      !session._disposed &&
      isCurrent() &&
      session.controller.hasLoadedPage &&
      session.controller.errors.value == null;

  @override
  void adopt() {
    _adopted = true;
    onAdopt();
  }

  @override
  void dispose() {
    if (!_adopted) session.dispose();
  }
}
