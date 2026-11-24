import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';

import '../../../core/bookmarks/src/server_favorites/fetch_runner.dart';
import '../../../core/bookmarks/src/types/bookmark.dart';
import '../../../core/content/types.dart';
import '../posts/types.dart';
import '../works/bookmark_targets.dart';
import '../works/work_mapper.dart';

typedef PixivFavoriteBookmark = ({
  int illustId,
  Bookmark Function(DateTime at) draft,
});

/// One job walks two independent listings through the captured account client.
class PixivFavoritesSyncSource {
  PixivFavoritesSyncSource({
    required this.client,
    required this.access,
    required this.userId,
    required this.cancellation,
  }) {
    unawaited(cancellation.whenCancelled.then((_) => _cancelToken.cancel()));
  }

  final PixivClient client;
  final ContentAccessContext access;
  final int userId;
  final ServerFavoriteCancellation cancellation;
  final _cancelToken = CancelToken();
  var _visibility = PixivBookmarkVisibility.public;
  String? _cursor;
  var _ended = false;

  Future<ServerFavoritePage<PixivFavoriteBookmark>> fetchPage() async {
    if (_ended) throw StateError('Pixiv favorites are exhausted');
    cancellation.throwIfCancelled();
    final page = await client.getUserBookmarks(
      userId: userId,
      visibility: _visibility,
      maxBookmarkId: _cursor,
      cancelToken: _cancelToken,
    );
    cancellation.throwIfCancelled();

    _cursor = page.nextBookmarkId;
    if (_cursor == null) {
      if (_visibility == PixivBookmarkVisibility.public) {
        _visibility = PixivBookmarkVisibility.private;
      } else {
        _ended = true;
      }
    }
    return ServerFavoritePage(
      [for (final illust in page.illusts) ?_mapBookmark(illust)],
      hasMore: !_ended,
      cursorAdvanced: !_ended,
    );
  }

  PixivFavoriteBookmark? _mapBookmark(PixivIllustDto illust) {
    if (!pixivWorkIsVisible(illust)) return null;
    final id = illust.id!;
    if (PixivIllustType.parse(illust.type) == PixivIllustType.ugoira) {
      final post = pixivWorkPagePosts(illust, access).firstOrNull;
      if (post == null || (post.pixivData?.isRestricted ?? true)) return null;
      final target = PixivPageBookmarkTarget(access: access, post: post);
      return (
        illustId: id,
        draft: (at) => target.draft(currentAccess: access, at: at),
      );
    }
    final target = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(illust, access),
    );
    return (
      illustId: id,
      draft: (at) => target.draft(currentAccess: access, at: at),
    );
  }
}
