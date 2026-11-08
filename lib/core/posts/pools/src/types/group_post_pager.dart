import 'package:dio/dio.dart';

import '../../../../content/groups/group_source_provider.dart';
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
  });

  final ContentGroupSource source;
  final ContentReference reference;
  final int perPage;
  final String? orderKey;
  final bool Function() isCurrent;
  var _cancellation = CancelToken();
  final _cursors = <int, ContentCursor>{};
  var _generation = 0;
  var _initialRequested = false;
  int? _lastPage;
  var _disposed = false;

  Future<PostResult<Post>> fetch(int page) async {
    if (page < 1 || perPage < 1) throw ArgumentError('Invalid Group page');
    if (_disposed || _cancellation.isCancelled || !isCurrent())
      throw RequestCancelledError();
    if (page == 1) {
      _cancellation.cancel('Group Post projection refreshed');
      _cancellation = CancelToken();
      _generation++;
      _cursors.clear();
      _lastPage = null;
      if (_initialRequested) source.invalidate(reference);
      _initialRequested = true;
    } else if (_lastPage != null && page > _lastPage!) {
      return const PostResult(posts: [], total: null, hasMore: false);
    } else if (!_cursors.containsKey(page)) {
      throw StateError('Group page has no preceding cursor');
    }
    final generation = _generation;
    final query = GroupMemberQuery(
      reference: reference,
      orderKey: orderKey,
      requestedLimit: perPage,
      cursor: _cursors[page],
    );
    final batch = validateGroupMemberBatch(
      query,
      await runGroupRead(
        source,
        () => source.loadMembers(query),
        token: _cancellation,
        current: () => generation == _generation && isCurrent(),
      ),
    );
    if (generation != _generation ||
        _cancellation.isCancelled ||
        !isCurrent()) {
      throw RequestCancelledError();
    }
    final resolved = {
      for (final entry in batch.resolved) entry.reference.identity: entry,
    };
    final visible = <Post>[];
    for (final member in batch.page.items) {
      if (member.availability == MemberAvailability.unavailable) continue;
      if (resolved[member.reference.identity] case PostContentEntry(
        :final post,
      )) {
        visible.add(post);
      }
    }
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
    return PostResult(
      posts: visible,
      total: batch.page.total,
      maxPage: batch.page.total == null
          ? null
          : (batch.page.total! + perPage - 1) ~/ perPage,
      hasMore: next != null,
    );
  }

  void dispose() {
    _disposed = true;
    _cancellation.cancel('Group Post projection disposed');
  }
}
