import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';

/// One account/privacy owns a cursor. The native grid never walks skipped pages
/// or infers continuation from visible Work counts.
class PixivWorkFavoritesSession {
  PixivWorkFavoritesSession(this.load);
  final Future<PixivBookmarkPage> Function(String? cursor, CancelToken token)
  load;
  var _token = CancelToken();
  String? _cursor;
  var _nextPage = 1;
  var _ended = false;
  var _disposed = false;
  void dispose() {
    _disposed = true;
    _token.cancel('Pixiv Work favorites disposed');
  }

  Future<PixivIllustListResult> fetch(int page) async {
    if (_disposed) throw StateError('Pixiv Work favorites disposed');
    if (page == 1) {
      _token.cancel('Pixiv Work favorites refreshed');
      _token = CancelToken();
      _cursor = null;
      _nextPage = 1;
      _ended = false;
    }
    if (_ended) return const PixivIllustListResult();
    if (page != _nextPage) {
      throw StateError('Pixiv favorites require sequential pages');
    }
    final token = _token;
    final result = await load(_cursor, token);
    if (_disposed || token.isCancelled) {
      throw StateError('Pixiv Work favorites revoked');
    }
    _cursor = result.nextBookmarkId;
    _ended = !result.hasMore;
    _nextPage = page + 1;
    return PixivIllustListResult(
      illusts: result.illusts,
      hasMore: result.hasMore,
    );
  }
}
