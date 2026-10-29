part of 'pixiv_client.dart';

/// `all` is intentionally absent: support for this endpoint is unverified.
enum PixivBookmarkVisibility { public, private }

class PixivBookmarkPage {
  const PixivBookmarkPage(this.illusts, {this.nextBookmarkId});

  factory PixivBookmarkPage.fromJson(
    Map<String, dynamic> json, {
    required int userId,
    required PixivBookmarkVisibility visibility,
    String? previousBookmarkId,
  }) {
    final raw = json['illusts'];
    if (raw is! List) throw const FormatException('Missing Pixiv bookmark list');
    final illusts = <PixivIllustDto>[];
    for (final value in raw) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid Pixiv bookmark entry');
      }
      illusts.add(PixivIllustDto.fromJson(value));
    }
    final next = json['next_url'];
    if (next == null) return PixivBookmarkPage(List.unmodifiable(illusts));
    final uri = next is String ? Uri.tryParse(next) : null;
    if (uri == null || uri.scheme != 'https' ||
        uri.host != 'app-api.pixiv.net' || uri.userInfo.isNotEmpty ||
        uri.port != 443 || uri.hasFragment ||
        uri.path != '/v1/user/bookmarks/illust') {
      throw const FormatException('Invalid Pixiv bookmark continuation');
    }
    String? single(String key) {
      final values = uri.queryParametersAll[key];
      return values?.length == 1 ? values!.single : null;
    }
    final cursor = single('max_bookmark_id');
    if (single('user_id') != '$userId' ||
        single('restrict') != visibility.name ||
        !isPixivBookmarkCursor(cursor) ||
        (previousBookmarkId != null &&
          BigInt.parse(cursor!) >= BigInt.parse(previousBookmarkId))) {
      throw const FormatException('Invalid Pixiv bookmark cursor or scope');
    }
    return PixivBookmarkPage(List.unmodifiable(illusts), nextBookmarkId: cursor);
  }

  final List<PixivIllustDto> illusts;
  final String? nextBookmarkId;
  bool get hasMore => nextBookmarkId != null;
}

bool isPixivBookmarkCursor(String? value) =>
    value != null && RegExp(r'^[1-9][0-9]{0,29}$').hasMatch(value);

extension PixivBookmarksClient on PixivClient {
  Future<PixivBookmarkPage> getUserBookmarks({
    required int userId,
    PixivBookmarkVisibility visibility = PixivBookmarkVisibility.public,
    String? maxBookmarkId,
    CancelToken? cancelToken,
  }) async {
    if (userId <= 0) throw ArgumentError.value(userId, 'userId');
    if (maxBookmarkId != null && !isPixivBookmarkCursor(maxBookmarkId)) {
      throw const FormatException('Invalid Pixiv bookmark cursor');
    }
    final body = await _get(
      '/v1/user/bookmarks/illust',
      queryParameters: {
        'user_id': userId,
        'restrict': visibility.name,
        'filter': _kFilter,
        'max_bookmark_id': ?maxBookmarkId,
      },
      cancelToken: cancelToken,
      followRedirects: false,
    );
    return PixivBookmarkPage.fromJson(body,
      userId: userId, visibility: visibility, previousBookmarkId: maxBookmarkId,
    );
  }
}
