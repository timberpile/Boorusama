import '../../../../content/groups/prepared_group_reads.dart';

import 'package:foundation/foundation.dart';

import '../../../../content/groups/related_group_counts.dart';

import 'dart:collection';

import 'package:dio/dio.dart';

import '../../../../content/groups/group_source_provider.dart';
import '../../../../content/groups/group_members_provider.dart';
import '../../../../content/types.dart';
import '../../../../errors/types.dart';
import '../../../post/types.dart';

/// Projects shared Group membership into the existing Post grid controller.
/// Raw cursors advance independently of omitted or blacklisted Post results;
/// selection, filtering and viewport restoration stay owned by the Post grid.
final class GroupPostPager {
  GroupPostPager({
    required this.source,
    required this.reference,
    required this.perPage,
    required this.isCurrent,
    this.orderKey,
    this.isPaginated,
    this.relatedCounts,
    this.preparedReads,
    this.currentRefreshRevision,
    this.isForeground,
    this.loadSharedPage,
  });

  final PreparedGroupReads? preparedReads;
  final int Function()? currentRefreshRevision;
  final bool Function()? isForeground;
  ({List<Post> posts, int? count})? _preparedConsumption;

  void activate() {
    if (_disposed || !isCurrent() || isForeground?.call() == false) return;
    final prepared = _preparedConsumption;
    _preparedConsumption = null;
    if (prepared == null) return;
    source.didConsumeMembers(prepared.posts);
    final key = GroupMetadataKey(
      reference: reference,
      access: source.access.key,
    );
    relatedCounts?.publish(relatedCounts?.begin(key), prepared.count);
  }

  final RelatedGroupCounts? relatedCounts;
  final Future<GroupMemberBatch> Function(int page)? loadSharedPage;
  final ContentGroupSource source;
  final ContentReference reference;
  final int perPage;
  final String? orderKey;
  final bool Function()? isPaginated;
  final _members = <int, List<({String key, Post post})>>{};
  final bool Function() isCurrent;
  var _cancellation = CancelToken();
  final _cursors = <int, ContentCursor>{};
  var _generation = 0;
  var _initialRequested = false;
  int? _lastPage;
  var _disposed = false;

  Future<PostResult<Post>> fetch(int page) async {
    if (page < 1 || perPage < 1) throw ArgumentError('Invalid Group page');
    if (_disposed ||
        _cancellation.isCancelled ||
        !isCurrent() ||
        page > 1 && isForeground?.call() == false) {
      throw RequestCancelledError();
    }
    final indexed = source is IndexedGroupMemberSource;
    if (_lastPage != null && page > _lastPage!) {
      return const PostResult(posts: [], total: null, hasMore: false);
    }
    if (!indexed && page > 1 && !_cursors.containsKey(page)) {
      throw StateError('Group page has no preceding cursor');
    }
    _initialRequested = true;
    final generation = _generation;
    final countRead = relatedCounts?.begin(
      GroupMetadataKey(reference: reference, access: source.access.key),
    );
    final query = GroupMemberQuery(
      reference: reference,
      orderKey: orderKey,
      requestedLimit: perPage,
      cursor: indexed ? null : _cursors[page],
    );
    final batch = validateGroupMemberBatch(
      query,
      await (loadSharedPage != null && (isForeground?.call() ?? true)
          ? loadSharedPage!(page)
          : runGroupRead(
              source,
              () => page == 1 && preparedReads != null
                  ? TaskEither.tryCatch(
                      () => preparedReads!.firstPage((
                        reference: reference,
                        order: orderKey,
                        limit: perPage,
                        revision: currentRefreshRevision?.call() ?? 0,
                      )),
                      (error, _) => error is BooruError
                          ? error
                          : UnknownError(
                              error: error,
                              message: 'Prepared page failed',
                            ),
                    )
                  : switch (source) {
                      final IndexedGroupMemberSource indexedSource =>
                        indexedSource.loadMemberPage(
                          query,
                          page: page,
                        ),
                      _ => source.loadMembers(query),
                    },
              token: _cancellation,
              current: () =>
                  generation == _generation &&
                  isCurrent() &&
                  (page == 1 || (isForeground?.call() ?? true)),
            )),
    );
    if (generation != _generation ||
        _cancellation.isCancelled ||
        !isCurrent() ||
        page > 1 && isForeground?.call() == false) {
      throw RequestCancelledError();
    }
    final resolved = {
      for (final entry in batch.resolved) entry.reference.identity: entry,
    };
    final visible = <Post>[];
    final rows = <({String key, Post post})>[];
    final previousKeys = (isPaginated?.call() ?? false)
        ? const <String>{}
        : {
            for (final entry in _members.entries.where(
              (entry) => entry.key < page,
            ))
              for (final member in entry.value) member.key,
          };
    for (final member in batch.page.items) {
      if (member.availability == MemberAvailability.unavailable ||
          previousKeys.contains(member.memberKey)) {
        continue;
      }
      if (resolved[member.reference.identity] case PostContentEntry(
        :final post,
      )) {
        visible.add(post);
        rows.add((key: member.memberKey, post: post));
      }
    }
    if (isPaginated?.call() ?? false) _members.clear();
    _members[page] = rows;
    final next = batch.page.next;
    if (next != null) {
      if (next == query.cursor ||
          _cursors.entries.any(
            (entry) => entry.key <= page && entry.value == next,
          )) {
        throw StateError('Group cursor did not progress');
      }
      _cursors[page + 1] = next;
    } else {
      _lastPage = page;
    }
    if (isForeground?.call() == false) {
      _preparedConsumption = (posts: visible, count: batch.page.total);
    } else {
      source.didConsumeMembers(visible);
      relatedCounts?.publish(countRead, batch.page.total);
    }
    return PostResult(
      posts: visible,
      total: batch.page.total,
      pageSize: perPage,
      maxPage: (batch.page.sourceTotal ?? batch.page.total) == null
          ? null
          : ((batch.page.sourceTotal ?? batch.page.total)! + perPage - 1) ~/
                perPage,
      hasMore: next != null,
    );
  }

  /// Explicit refresh revokes pending reads and drops both source and projection caches.
  bool refresh() {
    _cancellation.cancel('Group Post projection refreshed');
    _cancellation = CancelToken();
    _generation++;
    _cursors.clear();
    _members.clear();
    _preparedConsumption = null;
    _lastPage = null;
    if (_initialRequested) {
      preparedReads?.invalidate(
        reference,
        currentRefreshRevision?.call() ?? 0,
      );
      relatedCounts?.invalidate(
        GroupMetadataKey(reference: reference, access: source.access.key),
      );
      source.invalidate(reference);
    }
    return _initialRequested;
  }

  /// Selection belongs to a source membership, independently of Post identity.
  List<Object> selectionKeys(List<Post> posts) {
    final keysByPost = HashMap<Post, Queue<String>>.identity();
    for (final page in (_members.keys.toList()..sort())) {
      for (final row in _members[page]!) {
        (keysByPost[row.post] ??= Queue()).add(row.key);
      }
    }
    return [
      for (final post in posts)
        if (keysByPost[post] case final keys? when keys.isNotEmpty)
          (reference, orderKey, keys.removeFirst())
        else
          Object(),
    ];
  }

  void dispose() {
    _disposed = true;
    _cancellation.cancel('Group Post projection disposed');
  }
}

/// Projects one already shared source page, including an empty filtered page.
/// Source page boundaries prevent filling a grid by crawling extra API pages.
Future<GroupMemberBatch> readSharedGroupPostPage({
  required int page,
  required Future<GroupMembersState> Function() read,
  required Future<void> Function() loadNext,
}) async {
  var snapshot = await read();
  while (snapshot.pageEnds.length < page && snapshot.next != null) {
    if (snapshot.nextPageError case final error?) throw error;
    final before = snapshot.pageEnds.length;
    await loadNext();
    snapshot = await read();
    if (snapshot.nextPageError case final error?) throw error;
    if (snapshot.pageEnds.length <= before) break;
  }
  final offset = page <= 1
      ? 0
      : snapshot.pageEnds.elementAtOrNull(page - 2) ?? snapshot.members.length;
  final end =
      snapshot.pageEnds.elementAtOrNull(page - 1) ?? snapshot.members.length;
  final rows = snapshot.members.sublist(offset, end);
  final readable = rows
      .where((m) => m.availability != MemberAvailability.unavailable)
      .map((m) => m.reference.identity)
      .toSet();
  return (
    page: ContentPage(
      items: rows,
      total: snapshot.sourceTotal,
      next: snapshot.pageEnds.length > page || snapshot.next != null
          ? ContentCursor('shared-page:${page + 1}')
          : null,
    ),
    resolved: snapshot.resolved.values
        .where((entry) => readable.contains(entry.reference.identity))
        .toList(),
  );
}
