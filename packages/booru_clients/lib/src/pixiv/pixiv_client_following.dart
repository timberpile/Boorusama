part of 'pixiv_client.dart';

class PixivFollowingArtist {
  const PixivFollowingArtist({required this.user, this.illusts = const []});
  final PixivIllustUser user;
  final List<PixivIllustDto> illusts;
}

class PixivFollowingPage {
  const PixivFollowingPage(this.artists, {this.nextOffset});

  factory PixivFollowingPage.fromJson(
    Map<String, dynamic> json, {
    required int userId,
    required PixivFollowRestrict restrict,
    required int offset,
  }) {
    final raw = json['user_previews'];
    if (raw is! List)
      throw const FormatException('Missing Pixiv following list');
    final artists = <PixivFollowingArtist>[];
    for (final value in raw) {
      if (value is! Map<String, dynamic> ||
          value['user'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid Pixiv artist entry');
      }
      final user = PixivIllustUser.fromJson(
        value['user'] as Map<String, dynamic>,
      );
      if (user.id == null || user.id! <= 0) {
        throw const FormatException('Missing Pixiv artist identity');
      }
      final previews = value['illusts'];
      artists.add(
        PixivFollowingArtist(
          user: user,
          illusts: List.unmodifiable([
            if (previews is List)
              for (final preview in previews.take(3))
                if (preview is Map<String, dynamic>)
                  PixivIllustDto.fromJson(preview),
          ]),
        ),
      );
    }
    final next = json['next_url'];
    if (next == null) return PixivFollowingPage(List.unmodifiable(artists));
    final uri = next is String ? Uri.tryParse(next) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'app-api.pixiv.net' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment ||
        uri.path != '/v1/user/following') {
      throw const FormatException('Invalid Pixiv following continuation');
    }
    String? single(String key) {
      final values = uri.queryParametersAll[key];
      return values?.length == 1 ? values!.single : null;
    }

    final nextOffset = int.tryParse(single('offset') ?? '');
    if (single('user_id') != '$userId' ||
        single('restrict') != restrict.value ||
        nextOffset == null ||
        nextOffset <= offset ||
        nextOffset > 2147483647) {
      throw const FormatException('Invalid Pixiv following offset or scope');
    }
    return PixivFollowingPage(
      List.unmodifiable(artists),
      nextOffset: nextOffset,
    );
  }

  final List<PixivFollowingArtist> artists;
  final int? nextOffset;
  bool get hasMore => nextOffset != null;
}

extension PixivFollowingUsersClient on PixivClient {
  Future<PixivFollowingPage> getFollowingUsers({
    required int userId,
    PixivFollowRestrict restrict = PixivFollowRestrict.public,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    if (userId <= 0) throw ArgumentError.value(userId, 'userId');
    if (offset < 0 || offset > 2147483647)
      throw ArgumentError.value(offset, 'offset');
    if (restrict == PixivFollowRestrict.all) {
      throw ArgumentError('All is not verified for Pixiv following users');
    }
    final body = await _get(
      '/v1/user/following',
      queryParameters: {
        'user_id': userId,
        'restrict': restrict.value,
        'offset': offset,
      },
      cancelToken: cancelToken,
      followRedirects: false,
    );
    return PixivFollowingPage.fromJson(
      body,
      userId: userId,
      restrict: restrict,
      offset: offset,
    );
  }
}
