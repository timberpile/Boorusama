import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';

import '../../../../blacklists/providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../configs/config/types.dart';
import '../../../../boorus/booru/types.dart';

import '../../../../bookmarks/src/providers/bookmark_provider.dart';
import '../../../../bookmarks/src/types/content_group_bookmark.dart';
import '../../../../bookmarks/src/types/legacy_group_bookmark.dart';
import '../../../../content/groups/group_capability.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/types.dart';
import '../../../../settings/providers.dart';
import '../../../related/related_posts_order_value.dart';
import '../types/media_group_checkpoint.dart';
import '../types/group_order_candidate.dart';
import '../../../../errors/types.dart';
import '../types/viewer_entry.dart';
import 'viewer_source_access_provider.dart';

bool supportsGroupReading(GroupViewerEntry entry) =>
    switch (entry.contentReference.engine) {
      BooruType.pixiv => entry.contentReference.sourceKey.startsWith('work:'),
      BooruType.nhentai => entry.contentReference.sourceKey.startsWith(
        'gallery:',
      ),
      BooruType.danbooru =>
        entry.contentReference.sourceKey.startsWith('pool:') ||
            entry.contentReference.sourceKey.startsWith('related:'),
      _ => false,
    };

/// Reading choices are retained by the viewer's bounded occurrence window.
/// Neither the source envelope nor the saved Group identity owns a view mode.
final groupReadingProvider = NotifierProvider.autoDispose
    .family<GroupReadingController, GroupReadingState, GroupViewerEntry>(
      GroupReadingController.new,
      dependencies: [
        viewerSourceAccessProvider,
        booruGroupCapabilityProvider,
        contentGroupSourceStateProvider,
        groupDetailsProvider,
        groupMembersProvider,
        bookmarkProvider,
        settingsProvider,
        listingSettingsForAccessProvider,
      ],
    );

enum GroupSortPhase { idle, preparing, persisting, paused }

enum GroupOrderResult { unchanged, applied, paused }

class GroupReadingState {
  const GroupReadingState({
    required this.layout,
    required this.orderKey,
    required this.checkpoint,
    this.initializing = false,
    this.returnToTimeline = false,
    this.pendingOrderKey,
    this.sortPhase = GroupSortPhase.idle,
  });
  final GroupLayout layout;
  final String? orderKey;
  final MediaGroupCheckpoint checkpoint;
  final bool initializing;
  final bool returnToTimeline;
  final String? pendingOrderKey;
  final GroupSortPhase sortPhase;
  bool get sorting =>
      sortPhase == GroupSortPhase.preparing ||
      sortPhase == GroupSortPhase.persisting;
}

class GroupReadingController
    extends AutoDisposeFamilyNotifier<GroupReadingState, GroupViewerEntry> {
  GroupLayout? _layout;
  String? _order;
  var _drilledIn = false;
  _GroupOrderAttempt? _attempt;
  var _requestSerial = 0;
  PrepareGroupTimelineOrder? _timelinePreparation;
  PrepareGroupTimelineOrder? get timelinePreparation => _timelinePreparation;
  var _fixedOrder = false;
  var _poolMetadataReady = false;
  String? _restoredPoolOrder;
  late GroupViewerEntry _entry;
  MediaGroupCheckpoint? _checkpoint;
  var _disposed = false;

  @override
  GroupReadingState build(GroupViewerEntry entry) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _entry = entry;
    final reference = entry.contentReference;
    final presentation = ref
        .watch(
          booruGroupCapabilityProvider(reference.engine),
        )
        ?.presentation;
    final binding = entry.source;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    var summary = entry.summary;
    var initializing = false;
    _poolMetadataReady = false;
    if (reference.sourceKey.startsWith('pool:') &&
        access != null &&
        access.accepts(reference)) {
      final source = ref.watch(contentGroupSourceStateProvider(access.key));
      initializing = source.isLoading;
      if (source.asData != null) {
        final details = ref.watch(
          groupDetailsProvider(
            GroupMetadataKey(
              reference: reference,
              access: access.key,
            ),
          ),
        );
        initializing = details.isLoading;
        if (!details.isLoading && !details.hasError) {
          _poolMetadataReady = true;
          summary = details.requireValue.summary;
        }
      }
    }
    var order = _order;
    if (reference.sourceKey.startsWith('related:')) {
      final library = ref.watch(bookmarkProvider);
      initializing = order == null && library.isLoading;
      final id = library.valueOrNull?.idByContent[reference.identity];
      final saved = library.valueOrNull?.byId[id];
      order ??= (switch (saved) {
        RelatedBookmark(:final preferredOrder?) => preferredOrder,
        LegacyRelatedGroupBookmark(:final preferredOrder?) => preferredOrder,
        _ => ref.watch(settingsProvider).relatedPostsOrder,
      }).name;
    } else if (reference.sourceKey.startsWith('pool:') ||
        reference.sourceKey.startsWith('work:')) {
      order ??= 'order';
    }
    _fixedOrder = reference.sourceKey.startsWith('work:');
    if (_fixedOrder) {
      order = 'order';
      _order = order;
    } else if (_poolMetadataReady && _restoredPoolOrder != null) {
      order = _restoredPoolOrder;
      _order = order;
    }
    if (_poolMetadataReady) _restoredPoolOrder = null;
    if (!initializing) _order ??= order;
    return GroupReadingState(
      layout:
          _layout ?? presentation?.layoutFor(summary) ?? GroupLayout.memberGrid,
      orderKey: order,
      checkpoint: _checkpoint ??= MediaGroupCheckpoint(
        memberKey: entry.initialMemberKey,
      ),
      initializing: initializing,
      returnToTimeline: _drilledIn,
      pendingOrderKey: _attempt?.key.orderKey,
      sortPhase: _attempt?.phase ?? GroupSortPhase.idle,
    );
  }

  void show(GroupLayout layout, {String? memberKey, bool drillIn = false}) {
    cancelOrder();
    if (memberKey != null) state.checkpoint.memberKey = memberKey;
    if (memberKey == null) _captureFirstMember();
    _layout = layout;
    _drilledIn = drillIn && layout == GroupLayout.mediaPager;
    _publish();
  }

  void followSwipe(GroupLayout layout) {
    cancelOrder();
    if (_layout == layout && !_drilledIn) return;
    _layout = layout;
    _drilledIn = false;
    _publish();
  }

  void _captureFirstMember() {
    if (state.checkpoint.memberKey != null) return;
    final binding = _entry.source;
    final access = binding == null
        ? null
        : ref.read(viewerSourceAccessProvider(binding));
    if (access == null) return;
    final members = ref
        .read(
          groupMembersProvider(
            GroupLoadKey(
              reference: _entry.contentReference,
              access: access.key,
              orderKey: state.orderKey,
              requestedLimit: ref
                  .read(listingSettingsForAccessProvider(access.key))
                  .postsPerPage,
            ),
          ),
        )
        .asData
        ?.value
        .members;
    if (members != null && members.isNotEmpty) {
      state.checkpoint.select(members.first);
    }
  }

  void _publish() {
    state = GroupReadingState(
      layout: _layout ?? state.layout,
      orderKey: _order ?? state.orderKey,
      checkpoint: state.checkpoint,
      initializing: state.initializing,
      returnToTimeline: _drilledIn,
      pendingOrderKey: _attempt?.key.orderKey,
      sortPhase: _attempt?.phase ?? GroupSortPhase.idle,
    );
  }

  /// Reuses the native Pool gallery's route-local order checkpoint.
  void restorePoolOrder(String order) {
    if (!_entry.contentReference.sourceKey.startsWith('pool:') ||
        !['order', 'latest', 'oldest'].contains(order)) {
      return;
    }
    // Resolve the live Group envelope before restoring the route checkpoint.
    if (!_poolMetadataReady) {
      _restoredPoolOrder = order;
      return;
    }
    if (_fixedOrder || order == state.orderKey) return;
    _order = order;
    _publish();
  }

  void attachTimeline(PrepareGroupTimelineOrder prepare) {
    _timelinePreparation = prepare;
  }

  void detachTimeline(PrepareGroupTimelineOrder? prepare) {
    if (!identical(_timelinePreparation, prepare)) return;
    _timelinePreparation = null;
    cancelOrder();
  }

  void cancelOrder() {
    final attempt = _attempt;
    if (attempt == null) return;
    _attempt = null;
    attempt.cancel();
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      final checkpoint = _checkpoint;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed &&
            _attempt == null &&
            identical(_checkpoint, checkpoint)) {
          _publish();
        }
      });
    } else {
      _publish();
    }
  }

  Future<GroupOrderResult> setOrder(String order) async {
    if (state.sorting) return GroupOrderResult.unchanged;
    if (order == state.orderKey) {
      cancelOrder();
      return GroupOrderResult.unchanged;
    }
    if (_fixedOrder) throw const FormatException('Fixed Group order');
    final reference = _entry.contentReference;
    final related = reference.sourceKey.startsWith('related:');
    if (related
        ? !['oldest', 'newest'].contains(order)
        : !['order', 'latest', 'oldest'].contains(order)) {
      throw const FormatException('Unsupported Group order');
    }
    final binding = _entry.source;
    if (binding == null) return GroupOrderResult.unchanged;
    final access = ref.read(viewerSourceAccessProvider(binding));
    if (access == null || access.config == null || !access.accepts(reference)) {
      return GroupOrderResult.unchanged;
    }
    final source = ref
        .read(contentGroupSourceStateProvider(access.key))
        .asData
        ?.value;
    if (source == null) return GroupOrderResult.unchanged;
    final listing = ref.read(
      listingSettingsForAccessProvider(access.key),
    );
    final bookmarkFilter = ref.read(settingsProvider).bookmarkFilterType;
    final key = GroupLoadKey(
      reference: reference,
      access: access.key,
      orderKey: order,
      requestedLimit: listing.postsPerPage,
    );
    final revision = ref.read(groupRefreshRevisionProvider(key.metadata));
    final reading = state;
    final checkpoint = reading.checkpoint;
    final selected = checkpoint.memberKey;
    final applied = reading.orderKey;
    final pending = _attempt;
    final attempt = pending != null && pending.key == key && pending.isCurrent()
        ? pending
        : _GroupOrderAttempt(
            key: key,
            serial: ++_requestSerial,
            owner: ref.keepAlive(),
          );
    if (!identical(pending, attempt)) pending?.cancel();
    _attempt = attempt;
    final container = ref.container;
    attempt.isCurrent = () {
      if (!identical(_attempt, attempt) ||
          attempt.serial != _requestSerial ||
          attempt.cancellation.isCancelled) {
        return false;
      }
      final now = container.read(viewerSourceAccessProvider(binding));
      final currentReading = state;
      return (now?.hasSameAuthorization(access) ?? false) &&
          identical(
            container
                .read(contentGroupSourceStateProvider(access.key))
                .asData
                ?.value,
            source,
          ) &&
          container.read(groupRefreshRevisionProvider(key.metadata)) ==
              revision &&
          container.read(listingSettingsForAccessProvider(access.key)) ==
              listing &&
          container.read(settingsProvider).bookmarkFilterType ==
              bookmarkFilter &&
          identical(currentReading.checkpoint, checkpoint) &&
          checkpoint.memberKey == selected &&
          currentReading.layout == reading.layout &&
          currentReading.orderKey == applied;
    };
    if (!identical(attempt, pending)) {
      void monitor<T>(ProviderListenable<T> provider) {
        final subscription = ref.container.listen(provider, (_, _) {
          if (identical(_attempt, attempt) && !attempt.isCurrent()) {
            cancelOrder();
          }
        });
        attempt.cleanup.add(subscription.close);
      }

      monitor(viewerSourceAccessProvider(binding));
      monitor(contentGroupSourceStateProvider(access.key));
      monitor(groupRefreshRevisionProvider(key.metadata));
      monitor(listingSettingsForAccessProvider(access.key));
      monitor(settingsProvider);
      final blacklist = ref.container.listen(
        blacklistTagsProvider(access.config!.filter),
        (previous, next) {
          if (identical(_attempt, attempt) &&
              (previous?.hasValue ?? false) &&
              previous?.valueOrNull != next.valueOrNull) {
            cancelOrder();
          }
        },
      );
      attempt.cleanup.add(blacklist.close);
    }
    attempt.phase = GroupSortPhase.preparing;
    _publish();
    GroupOrderCandidate? timeline;
    var adopted = false;
    try {
      GroupMembersState? members;
      if (reading.layout == GroupLayout.memberGrid) {
        final prepare = _timelinePreparation;
        if (prepare == null) throw StateError('Group Timeline is unavailable');
        timeline = await prepare(order, attempt.cancellation);
      } else {
        members = await _prepareMedia(attempt);
        if (!attempt.isCurrent()) return GroupOrderResult.unchanged;
        if (members == null) {
          attempt.phase = GroupSortPhase.paused;
          _publish();
          return GroupOrderResult.paused;
        }
      }
      if (!attempt.isCurrent()) return GroupOrderResult.unchanged;
      if (timeline != null && !timeline.isReady) {
        throw StateError('Group grid changed');
      }
      if (members != null && checkpoint.adoptMediaOrder == null) {
        throw StateError('Group media presenter changed');
      }
      if (!await _waitForIdle(attempt, checkpoint, timeline)) {
        return GroupOrderResult.unchanged;
      }
      attempt.phase = GroupSortPhase.persisting;
      _publish();
      if (related) {
        final library = ref.read(bookmarkProvider).valueOrNull;
        final id = library?.idByContent[reference.identity];
        final record = library?.byId[id];
        if (id != null && record != null) {
          final result = await ref
              .read(bookmarkProvider.notifier)
              .commitRelatedOrder(
                id,
                RelatedPostsOrder.values.byName(order),
                reader: access.config,
                expectedRecord: record,
                callerCurrent: attempt.isCurrent,
                callerCancellation: attempt.cancellation,
              );
          if (result == RelatedOrderCommitResult.stale) {
            if (attempt.isCurrent()) {
              throw StateError('Related bookmark changed');
            }
            return GroupOrderResult.unchanged;
          }
        }
      }
      if (!await _waitForIdle(attempt, checkpoint, timeline)) {
        return GroupOrderResult.unchanged;
      }
      if (timeline != null) {
        if (!timeline.isReady) throw StateError('Group grid changed');
        timeline.adopt();
      } else {
        final snapshot = members!;
        if (checkpoint.adoptMediaOrder?.call(key, snapshot) != true) {
          throw StateError('Group media presenter changed');
        }
        checkpoint.memberKey = snapshot.members.firstOrNull?.memberKey;
      }
      _order = order;
      _attempt = null;
      adopted = true;
      _publish();
      return GroupOrderResult.applied;
    } catch (_) {
      if (!attempt.isCurrent()) return GroupOrderResult.unchanged;
      rethrow;
    } finally {
      timeline?.dispose();
      if (adopted) {
        // Retain the prepared provider until the new consumers attach.
        SchedulerBinding.instance.addPostFrameCallback((_) => attempt.cancel());
      } else if (attempt.phase != GroupSortPhase.paused ||
          !attempt.isCurrent()) {
        if (identical(_attempt, attempt)) {
          _attempt = null;
          _publish();
        }
        attempt.cancel();
      }
    }
  }

  Future<bool> _waitForIdle(
    _GroupOrderAttempt attempt,
    MediaGroupCheckpoint checkpoint,
    GroupOrderCandidate? timeline,
  ) async {
    while (attempt.isCurrent() &&
        (!(checkpoint.canAdoptOrder?.call() ?? true) ||
            !(timeline?.canAdopt ?? true))) {
      await Future.any([
        SchedulerBinding.instance.endOfFrame,
        attempt.cancellation.whenCancel,
      ]);
    }
    return attempt.isCurrent();
  }

  Future<GroupMembersState?> _prepareMedia(_GroupOrderAttempt attempt) async {
    final provider = groupMembersProvider(attempt.key);
    final cached = ref.read(provider).valueOrNull;
    attempt.membership ??= ref.container.listen(provider, (_, _) {});
    Future<GroupMembersState> loadSnapshot() => Future.any([
      ref.read(provider.future),
      attempt.cancellation.whenCancel.then<GroupMembersState>(
        (_) => throw RequestCancelledError(),
      ),
    ]);
    var reads = cached?.firstPageLoaded ?? false ? 0 : 1;
    var snapshot = await loadSnapshot();
    while (attempt.isCurrent()) {
      if (snapshot.members.firstOrNull case final first?) {
        if (first.availability == MemberAvailability.unavailable ||
            (first.availability == MemberAvailability.available &&
                snapshot.resolved[first.reference.identity]
                    is PostContentEntry)) {
          return snapshot;
        }
        throw StateError('First Group member is unresolved');
      }
      if (snapshot.nextPageError case final error?) throw error;
      if (snapshot.next == null) return snapshot;
      if (reads == 8) return null;
      reads++;
      final before = snapshot.pageEnds.length;
      await Future.any([
        ref.read(provider.notifier).loadNext(),
        attempt.cancellation.whenCancel,
      ]);
      if (!attempt.isCurrent()) throw RequestCancelledError();
      snapshot = await loadSnapshot();
      if (snapshot.nextPageError case final error?) throw error;
      if (snapshot.pageEnds.length <= before) {
        throw StateError('Group page did not advance');
      }
    }
    throw RequestCancelledError();
  }
}

final class _GroupOrderAttempt {
  _GroupOrderAttempt({
    required this.key,
    required this.serial,
    required this.owner,
  });
  final GroupLoadKey key;
  final int serial;
  final KeepAliveLink owner;
  final cancellation = CancelToken();
  final cleanup = <void Function()>[];
  var phase = GroupSortPhase.preparing;
  late bool Function() isCurrent;
  ProviderSubscription<AsyncValue<GroupMembersState>>? membership;

  void cancel() {
    if (cancellation.isCancelled) return;
    cancellation.cancel('Group order changed');
    for (final close in cleanup) {
      close();
    }
    membership?.close();
    owner.close();
  }
}
