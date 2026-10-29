import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';

import '../../../core/errors/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../posts/parser.dart';

typedef PixivBookmarkLoader = Future<PixivBookmarkPage> Function(
  String? cursor, CancelToken cancellation,
);

/// One account and visibility filter per instance. Never walks skipped pages.
class PixivFavoritesSession {
  PixivFavoritesSession({required this.load, required this.origin});
  final PixivBookmarkLoader load;
  final PostOrigin origin;
  var _cancel = CancelToken();
  var _disposed = false;
  var _expectedPage = 1;
  var _ended = false;
  String? _cursor;
  int? _lastPage;
  PostResult<Post>? _lastResult;

  void dispose() {
    _disposed = true;
    _cancel.cancel('Pixiv favorites scope closed');
  }

  PostsOrError<Post> getPosts(int page) => TaskEither.tryCatch(
    () => _fetch(page),
    (error, _) => switch (error) {
      DioException(type: DioExceptionType.cancel) => RequestCancelledError(),
      DioException(error: ApiCooldownException(:final retryAt)) =>
        RateLimitedError(retryAt),
      _ => AppError(type: AppErrorType.loadDataFromServerFailed,
        message: 'Could not load Pixiv favorites.'),
    },
  );

  Future<PostResult<Post>> _fetch(int page) async {
    if (_disposed) throw _cancel.cancelError!;
    if (page < 1) throw ArgumentError.value(page, 'page');
    if (page == 1) {
      _cancel.cancel('Pixiv favorites refreshed');
      _cancel = CancelToken();
      _cursor = null;
      _expectedPage = 1;
      _ended = false;
      _lastPage = null;
      _lastResult = null;
    } else if (page == _lastPage) {
      return _lastResult!;
    }
    if (_ended) return const PostResult(posts: [], total: null, hasMore: false);
    if (page != _expectedPage) {
      throw StateError('Pixiv favorites require sequential pagination');
    }
    final token = _cancel;
    final result = await load(_cursor, token);
    if (token.isCancelled) throw token.cancelError!;
    final posts = bindPostResultOrigin(PostResult(
      posts: illustDtosToPosts(result.illusts),
      total: null,
      hasMore: result.hasMore,
      maxPage: result.hasMore ? null : page,
    ), origin: origin);
    _cursor = result.nextBookmarkId;
    _ended = !result.hasMore;
    _expectedPage = page + 1;
    _lastPage = page;
    _lastResult = posts;
    return posts;
  }
}
