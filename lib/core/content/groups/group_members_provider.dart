import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../errors/types.dart';
import '../content_access.dart';
import '../content_entry.dart';
import '../content_page.dart';
import '../content_reference.dart';
import 'group_member.dart';
import 'group_source.dart';
import 'group_source_provider.dart';

final class GroupMembersState extends Equatable {
  GroupMembersState({
    required Iterable<GroupMember> members,
    required Map<ContentIdentity, ContentEntry> resolved,
    this.next,
    this.sourceTotal,
    this.firstPageLoaded = false,
    this.loadingMore = false,
    this.nextPageError,
    required this.generation,
  }) : members = List.unmodifiable(members),
       resolved = Map.unmodifiable(resolved);
  final List<GroupMember> members;
  final Map<ContentIdentity, ContentEntry> resolved;
  final ContentCursor? next;
  final int? sourceTotal;
  final bool firstPageLoaded;
  final bool loadingMore;
  final BooruError? nextPageError;
  final int generation;
  GroupMembersState copyWith({
    bool? loadingMore,
    BooruError? Function()? nextPageError,
  }) => GroupMembersState(
    members: members,
    resolved: resolved,
    next: next,
    sourceTotal: sourceTotal,
    firstPageLoaded: firstPageLoaded,
    loadingMore: loadingMore ?? this.loadingMore,
    nextPageError: nextPageError == null ? this.nextPageError : nextPageError(),
    generation: generation,
  );
  @override
  List<Object?> get props => [
    members,
    resolved,
    next,
    sourceTotal,
    firstPageLoaded,
    loadingMore,
    nextPageError,
    generation,
  ];
}

final groupMembersProvider = AsyncNotifierProvider.autoDispose
    .family<GroupMembersController, GroupMembersState, GroupLoadKey>(
      GroupMembersController.new,
      dependencies: [
        contentGroupSourceProvider,
        groupSummaryProvider,
        groupDetailsProvider,
      ],
    );

class GroupMembersController
    extends AutoDisposeFamilyAsyncNotifier<GroupMembersState, GroupLoadKey> {
  late GroupLoadKey _key;
  ContentGroupSource? _source;
  CancelToken? _cancel;
  var _generation = 0;
  var _active = true;
  Future<void>? _nextPending;
  final _seenCursors = <String>{};
  final _memberIndex = <String, int>{};
  final _readableOccurrences = <ContentIdentity, int>{};

  @override
  Future<GroupMembersState> build(GroupLoadKey key) {
    _key = key;
    _active = true;
    final generation = _reset();
    final cancel = _cancel!;
    ref.onDispose(() {
      if (generation == _generation) _active = false;
      cancel.cancel('Group members disposed');
    });
    _source = null;
    final source = ref.watch(contentGroupSourceProvider(key.access));
    _source = source;
    return _initial(source, generation);
  }

  GroupMembersState _empty(int generation) => GroupMembersState(
    members: const [],
    resolved: const {},
    generation: generation,
  );
  int _reset() {
    _cancel?.cancel('Group generation changed');
    _cancel = CancelToken();
    _generation++;
    _nextPending = null;
    _seenCursors.clear();
    _memberIndex.clear();
    _readableOccurrences.clear();
    return _generation;
  }

  bool _current(int generation, ContentGroupSource source) {
    if (!_active || generation != _generation) return false;
    try {
      return identical(
        ref.read(contentGroupSourceProvider(_key.access)),
        source,
      );
      // BooruError is this application's domain failure type despite its base.
      // ignore: avoid_catching_errors
    } on BooruError {
      return false;
    } on FormatException {
      return false;
    }
  }

  Future<GroupMembersState> _initial(
    ContentGroupSource source,
    int generation,
  ) async {
    final query = GroupMemberQuery(
      reference: _key.reference,
      orderKey: _key.orderKey,
    );
    final batch = await _request(source, query, generation);
    if (!_current(generation, source)) throw RequestCancelledError();
    return _append(_empty(generation), query, batch);
  }

  Future<GroupMemberBatch> _request(
    ContentGroupSource source,
    GroupMemberQuery query,
    int generation,
  ) async {
    if (!source.access.accepts(query.reference)) {
      throw const FormatException('Foreign Group request');
    }
    final batch = await runGroupRead(
      source,
      () => source.loadMembers(query),
      token: _cancel!,
      current: () => _current(generation, source),
    );
    return validateGroupMemberBatch(query, batch);
  }

  Future<void> loadNext() {
    if (_nextPending case final pending?) return pending;
    final before = state.valueOrNull;
    final source = _source;
    if (before == null ||
        !before.firstPageLoaded ||
        before.next == null ||
        source == null ||
        !_active) {
      return Future.value();
    }
    final generation = _generation;
    late final Future<void> pending;
    pending = _loadNext(before, source, generation).whenComplete(() {
      if (identical(_nextPending, pending)) _nextPending = null;
    });
    _nextPending = pending;
    return pending;
  }

  Future<void> retryNext() => loadNext();

  Future<void> _loadNext(
    GroupMembersState before,
    ContentGroupSource source,
    int generation,
  ) async {
    state = AsyncData(
      before.copyWith(loadingMore: true, nextPageError: () => null),
    );
    final query = GroupMemberQuery(
      reference: _key.reference,
      orderKey: _key.orderKey,
      cursor: before.next,
    );
    try {
      final batch = await _request(source, query, generation);
      if (_current(generation, source)) {
        state = AsyncData(_append(before, query, batch));
      }
    } catch (error) {
      if (_current(generation, source)) {
        state = AsyncData(
          before.copyWith(
            loadingMore: false,
            nextPageError: () => _error(error),
          ),
        );
      }
    }
  }

  Future<void> refresh() {
    final source = _source;
    if (source == null || !_active) return Future.value();
    // Clear already published members before the provider rebuild. Never publish
    // an empty success while an initial-load future is still pending.
    if (state.hasValue) state = AsyncData(_empty(_generation + 1));
    source.invalidate(_key.reference);
    ref.invalidate(groupSummaryProvider(_key.metadata));
    ref.invalidate(groupDetailsProvider(_key.metadata));
    ref.invalidateSelf();
    return ref
        .read(groupMembersProvider(_key).future)
        .then<void>((_) {}, onError: (Object error, StackTrace stack) {});
  }

  GroupMembersState _append(
    GroupMembersState before,
    GroupMemberQuery query,
    GroupMemberBatch batch,
  ) {
    final next = batch.page.next;
    if (next != null &&
        (next == query.cursor || _seenCursors.contains(next.token))) {
      throw AppError(
        type: AppErrorType.loadDataFromServerFailed,
        message: 'Group cursor did not progress',
      );
    }
    final members = [...before.members];
    final newIndices = <String, int>{};
    final visibilityDelta = <ContentIdentity, int>{};
    void adjust(GroupMember member, int delta) {
      if (member.availability == MemberAvailability.unavailable) return;
      visibilityDelta.update(
        member.reference.identity,
        (value) => value + delta,
        ifAbsent: () => delta,
      );
    }

    for (final member in batch.page.items) {
      final index = _memberIndex[member.memberKey];
      if (index == null) {
        newIndices[member.memberKey] = members.length;
        members.add(member);
        adjust(member, 1);
      } else {
        final old = members[index];
        const ContentReferenceCodec().requireCompatible(
          old.reference,
          member.reference,
        );
        if (old.sourcePosition != null &&
            member.sourcePosition != null &&
            old.sourcePosition != member.sourcePosition) {
          throw const FormatException(
            'Group occurrence changed source position',
          );
        }
        adjust(old, -1);
        adjust(member, 1);
        members[index] = GroupMember(
          reference: member.reference,
          memberKey: member.memberKey,
          sourcePosition: member.sourcePosition ?? old.sourcePosition,
          availability: member.availability,
        );
      }
    }
    final resolved = Map<ContentIdentity, ContentEntry>.of(before.resolved);
    for (final entry in batch.resolved) {
      final previous = resolved[entry.reference.identity];
      if (previous != null) {
        const ContentReferenceCodec().requireCompatible(
          previous.reference,
          entry.reference,
        );
        if (previous is PostContentEntry &&
            entry is PostContentEntry &&
            (previous.post.booruData.typeKey != entry.post.booruData.typeKey ||
                previous.post.booruData.schemaVersion !=
                    entry.post.booruData.schemaVersion)) {
          throw const FormatException('Incompatible hydrated Post payload');
        }
      }
      resolved[entry.reference.identity] = entry;
    }
    for (final entry in visibilityDelta.entries) {
      final count = (_readableOccurrences[entry.key] ?? 0) + entry.value;
      if (count == 0) resolved.remove(entry.key);
    }
    // Publish indexes only after the whole page has passed validation.
    _memberIndex.addAll(newIndices);
    for (final entry in visibilityDelta.entries) {
      final count = (_readableOccurrences[entry.key] ?? 0) + entry.value;
      if (count == 0) {
        _readableOccurrences.remove(entry.key);
      } else {
        _readableOccurrences[entry.key] = count;
      }
    }
    if (next != null) _seenCursors.add(next.token);
    return GroupMembersState(
      members: members,
      resolved: resolved,
      next: next,
      sourceTotal: batch.page.total ?? before.sourceTotal,
      firstPageLoaded: true,
      generation: _generation,
    );
  }

  static BooruError _error(Object error) => error is BooruError
      ? error
      : UnknownError(error: error, message: 'Unable to load Group members');
}
