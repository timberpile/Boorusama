import '../../../../posts/post/types.dart';
import '../types/search_following_feed.dart';
import '../types/search_subscription.dart';

typedef FeedSourcePageFetcher =
    Future<PostResult<Post>> Function(
      SearchSubscription source,
      int page,
    );

class FeedHistorySession {
  FeedHistorySession({
    required List<SearchSubscription> sources,
    required List<CachedFeedPost> recent,
    required FeedSourcePageFetcher fetchPage,
  }) : _cursors = [for (final source in sources) _FeedCursor(source)],
       _recent = List.unmodifiable(recent),
       _fetchPage = fetchPage,
       _knownIds = recent.map((post) => post.id).toSet(),
       _oldestRecent = recent.isEmpty ? null : recent.last.createdAt;

  final List<_FeedCursor> _cursors;
  final List<CachedFeedPost> _recent;
  final FeedSourcePageFetcher _fetchPage;
  final Set<int> _knownIds;
  final DateTime? _oldestRecent;
  final Map<int, PostResult<CachedFeedPost>> _loadedPages = {};
  var _initialized = false;

  Future<PostResult<CachedFeedPost>> load(int page) async {
    if (_loadedPages[page] case final result?) return result;
    if (page == 1 && _recent.isNotEmpty) {
      return _loadedPages[page] = PostResult(
        posts: _recent,
        total: null,
        hasMore: _cursors.isNotEmpty,
      );
    }
    if (!_initialized) {
      _initialized = true;
      await _fillEmptyCursors();
    }
    final posts = <CachedFeedPost>[];
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
      if (_knownIds.add(post.id) &&
          (_oldestRecent == null || !post.createdAt!.isAfter(_oldestRecent))) {
        posts.add(post);
      }
    }
    return _loadedPages[page] = PostResult(
      posts: posts,
      total: null,
      hasMore: _cursors.any(
        (cursor) => cursor.hasMore || cursor.current != null,
      ),
    );
  }

  Future<void> _fillEmptyCursors() async {
    final pending = _cursors
        .where((cursor) => cursor.hasMore && cursor.current == null)
        .toList();
    var next = 0;
    Object? failure;
    StackTrace? failureStack;
    Future<void> worker() async {
      while (next < pending.length) {
        final cursor = pending[next++];
        try {
          final result = await _fetchPage(cursor.source, cursor.page);
          cursor.page++;
          cursor.posts =
              [
                for (final post in result.posts)
                  if (post.createdAt != null) CachedFeedPost.fromPost(post),
              ]..sort((left, right) {
                final date = right.createdAt!.compareTo(left.createdAt!);
                return date == 0 ? right.id.compareTo(left.id) : date;
              });
          cursor.offset = 0;
          cursor.hasMore = result.hasMore ?? result.posts.isNotEmpty;
          if (cursor.posts.isEmpty) cursor.hasMore = false;
        } catch (error, stackTrace) {
          failure ??= error;
          failureStack ??= stackTrace;
        }
      }
    }

    await Future.wait([
      for (var index = 0; index < 3 && index < pending.length; index++)
        worker(),
    ]);
    if (failure case final error?) {
      Error.throwWithStackTrace(error, failureStack!);
    }
  }
}

class _FeedCursor {
  _FeedCursor(this.source);

  final SearchSubscription source;
  var page = 1;
  var offset = 0;
  var hasMore = true;
  List<CachedFeedPost> posts = const [];

  CachedFeedPost? get current => offset < posts.length ? posts[offset] : null;
}
