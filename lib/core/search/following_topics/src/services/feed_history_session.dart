import '../../../../posts/post/types.dart';
import '../types/following_topic.dart';

typedef FeedSourcePageFetcher =
    Future<PostResult<Post>> Function(
      FollowingTopic source,
      int page,
    );

class FeedHistorySession {
  FeedHistorySession({
    required List<FollowingTopic> sources,
    required List<Post> recent,
    required FeedSourcePageFetcher fetchPage,
  }) : _cursors = [for (final source in sources) _FeedCursor(source)],
       _recent = List.unmodifiable(recent),
       _fetchPage = fetchPage,
       _knownIds = recent.map(_postIdentity).toSet(),
       _oldestRecent = recent.isEmpty ? null : recent.last.createdAt;

  final List<_FeedCursor> _cursors;
  final List<Post> _recent;
  final FeedSourcePageFetcher _fetchPage;
  final Set<String> _knownIds;
  final DateTime? _oldestRecent;
  final Map<int, PostResult<Post>> _loadedPages = {};
  final List<Post> _pendingPosts = [];
  var _initialized = false;
  var _disposed = false;

  Set<String> get unavailableSourceIds => {
    for (final cursor in _cursors)
      if (cursor.failure != null) cursor.source.id,
  };

  bool get coverageIncomplete => unavailableSourceIds.isNotEmpty;

  void allowRecovery() {
    if (_disposed) return;
    for (final cursor in _cursors) {
      cursor.failure = null;
    }
    for (final entry in _loadedPages.entries.toList()) {
      if (entry.key == 1) continue;
      if (entry.value.posts.isEmpty) {
        _loadedPages.remove(entry.key);
      } else {
        _loadedPages[entry.key] = entry.value.copyWith(hasMore: () => true);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _pendingPosts.clear();
    _loadedPages.clear();
  }

  Future<PostResult<Post>> load(int page) async {
    if (_disposed) throw StateError('Feed history session closed');
    if (_loadedPages[page] case final result?) return result;
    if (page == 1 && _recent.isNotEmpty) {
      return _loadedPages[page] = PostResult(
        posts: _recent,
        total: null,
        hasMore: _cursors.any((cursor) => cursor.failure == null),
      );
    }
    if (!_initialized) {
      _initialized = true;
      await _fillEmptyCursors();
    }
    final posts = _pendingPosts;
    while (posts.length < 50) {
      await _fillEmptyCursors();
      final available = _cursors
          .where((cursor) => cursor.current != null)
          .toList();
      if (available.isEmpty) break;
      available.sort((left, right) {
        final date = right.current!.createdAt!.compareTo(
          left.current!.createdAt!,
        );
        return date == 0 ? right.current!.id.compareTo(left.current!.id) : date;
      });
      final cursor = available.first;
      final post = cursor.current!;
      cursor.offset++;
      if (_knownIds.add(_postIdentity(post)) &&
          (_oldestRecent == null || !post.createdAt!.isAfter(_oldestRecent))) {
        posts.add(post);
      }
    }
    final result = PostResult<Post>(
      posts: List.unmodifiable(posts),
      total: null,
      hasMore: _cursors.any(
        (cursor) =>
            cursor.failure == null &&
            (cursor.hasMore || cursor.current != null),
      ),
    );
    posts.clear();
    return _loadedPages[page] = result;
  }

  Future<void> _fillEmptyCursors() async {
    if (_disposed) throw StateError('Feed history session closed');
    final pending = _cursors
        .where(
          (cursor) =>
              cursor.hasMore &&
              cursor.current == null &&
              cursor.failure == null,
        )
        .toList();
    var next = 0;
    Future<void> worker() async {
      while (!_disposed && next < pending.length) {
        final cursor = pending[next++];
        try {
          final result = await _fetchPage(cursor.source, cursor.page);
          if (_disposed) return;
          cursor.page++;
          cursor.posts =
              [
                for (final post in result.posts)
                  if (post.createdAt != null) post,
              ]..sort((left, right) {
                final date = right.createdAt!.compareTo(left.createdAt!);
                return date == 0 ? right.id.compareTo(left.id) : date;
              });
          cursor.offset = 0;
          cursor.hasMore = result.hasMore ?? result.posts.isNotEmpty;
          if (cursor.posts.isEmpty) cursor.hasMore = false;
        } catch (error, stackTrace) {
          if (_disposed) return;
          cursor.failure = (error, stackTrace);
        }
      }
    }

    await Future.wait([
      for (var index = 0; index < 3 && index < pending.length; index++)
        worker(),
    ]);
    if (_disposed) throw StateError('Feed history session closed');
  }
}

String _postIdentity(Post post) {
  final origin = post.origin;
  final site = origin.sourceHost.isEmpty
      ? 'profile:${origin.profileIdHint ?? origin.booruId}'
      : '${origin.booruType.id}:${origin.sourceHost}';
  return '$site:${post.id}';
}

class _FeedCursor {
  _FeedCursor(this.source);

  final FollowingTopic source;
  var page = 1;
  var offset = 0;
  var hasMore = true;
  List<Post> posts = const [];
  (Object, StackTrace)? failure;

  Post? get current => offset < posts.length ? posts[offset] : null;
}
