import 'dart:convert';

import 'package:dio/dio.dart';

import 'pixiv_constants.dart';
import 'pixiv_headers.dart';
import 'types/types.dart';

const _kFilter = 'for_ios';

/// Read-only client for the Pixiv `app-api` (`https://app-api.pixiv.net`).
///
/// Every call attaches the full required header set (Authorization,
/// User-Agent, App-OS[-Version], App-Version, Accept-Language, Referer,
/// X-Client-Time, X-Client-Hash) PER REQUEST via dio `Options`. The injected
/// [dio]'s `BaseOptions.headers` is never mutated — it may be shared by
/// app-side code.
///
/// Pagination is offset-only: callers compute `offset = (page - 1) * 30`.
/// `next_url` is never fetched or resolved, only read as a has-more signal —
/// see [PixivIllustListResult.hasMore].
class PixivClient {
  PixivClient({
    required this.accessToken,
    Dio? dio,
    String baseUrl = kPixivApiBaseUrl,
    this.acceptLanguage = 'en-US',
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  final Dio _dio;

  /// Bearer token attached to every request. The client is immutable — when
  /// the token rotates, callers build a new [PixivClient].
  final String accessToken;

  /// Required or every `tags[].translated_name` in a response comes back
  /// null.
  final String acceptLanguage;

  Future<PixivIllustListResult> getRanking({
    required PixivRankingMode mode,
    DateTime? date,
    int page = 1,
  }) async {
    final body = await _get(
      '/v1/illust/ranking',
      queryParameters: {
        'mode': mode.value,
        'date': ?_formatDate(date),
        'offset': _offsetFor(page),
        'filter': _kFilter,
      },
    );

    return PixivIllustListResult.fromJson(body);
  }

  /// `GET /v2/illust/follow` — illusts from followed artists.
  ///
  /// [restrict] filters by whether the *follow relationship* is public or
  /// private, not by the artwork's own visibility — `all` (the default) is
  /// correct for a normal feed.
  Future<PixivIllustListResult> getFollowedIllusts({
    PixivFollowRestrict restrict = PixivFollowRestrict.all,
    required int page,
  }) async {
    final body = await _get(
      '/v2/illust/follow',
      queryParameters: {
        'restrict': restrict.value,
        'offset': _offsetFor(page),
        'filter': _kFilter,
      },
    );

    return PixivIllustListResult.fromJson(body);
  }

  /// `GET /v1/illust/recommended` — the personalized recommended feed.
  ///
  /// Requests `include_ranking_illusts=true` to match app behavior; the
  /// response's extra `ranking_illusts` section is ignored, only `illusts`
  /// is parsed.
  Future<PixivIllustListResult> getRecommendedIllusts({
    required int page,
  }) async {
    final body = await _get(
      '/v1/illust/recommended',
      queryParameters: {
        'include_ranking_illusts': true,
        'offset': _offsetFor(page),
        'filter': _kFilter,
      },
    );

    return PixivIllustListResult.fromJson(body);
  }

  Future<PixivIllustListResult> searchIllust({
    required String word,
    PixivSearchTarget searchTarget = PixivSearchTarget.partialMatchForTags,
    PixivSearchSort sort = PixivSearchSort.dateDesc,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  }) async {
    final body = await _get(
      '/v1/search/illust',
      queryParameters: {
        'word': word,
        'search_target': searchTarget.value,
        'sort': sort.value,
        'start_date': ?_formatDate(startDate),
        'end_date': ?_formatDate(endDate),
        'offset': _offsetFor(page),
        'filter': _kFilter,
      },
    );

    return PixivIllustListResult.fromJson(body);
  }

  /// Single un-paginated page of popular results. The non-Premium fallback
  /// for `sort=popular_desc`, which requires Premium.
  Future<PixivIllustListResult> popularPreviewIllust({
    required String word,
  }) async {
    final body = await _get(
      '/v1/search/popular-preview/illust',
      queryParameters: {'word': word, 'filter': _kFilter},
    );

    return PixivIllustListResult.fromJson(body);
  }

  Future<PixivIllustDto?> getIllustDetail({required int illustId}) async {
    final body = await _get(
      '/v1/illust/detail',
      queryParameters: {'illust_id': illustId},
    );

    final illust = body['illust'];
    if (illust is! Map<String, dynamic>) return null;

    return PixivIllustDto.fromJson(illust);
  }

  Future<PixivIllustListResult> getUserIllusts({
    required int userId,
    int page = 1,
  }) async {
    final body = await _get(
      '/v1/user/illusts',
      queryParameters: {
        'user_id': userId,
        'type': 'illust',
        'offset': _offsetFor(page),
        'filter': _kFilter,
      },
    );

    return PixivIllustListResult.fromJson(body);
  }

  Future<PixivUserDetailDto> getUserDetail({required int userId}) async {
    final body = await _get(
      '/v1/user/detail',
      queryParameters: {'user_id': userId, 'filter': _kFilter},
    );

    return PixivUserDetailDto.fromJson(body);
  }

  Future<List<PixivTag>> autocomplete({required String word}) async {
    final body = await _get(
      '/v2/search/autocomplete',
      queryParameters: {'word': word},
    );

    final tags = body['tags'];
    if (tags is! List) return const [];

    return tags
        .whereType<Map<String, dynamic>>()
        .map(PixivTag.fromJson)
        .toList();
  }

  Future<PixivUgoiraMetadataDto?> getUgoiraMetadata({
    required int illustId,
  }) async {
    final body = await _get(
      '/v1/ugoira/metadata',
      queryParameters: {'illust_id': illustId},
    );

    final metadata = body['ugoira_metadata'];
    if (metadata is! Map<String, dynamic>) return null;

    return PixivUgoiraMetadataDto.fromJson(metadata);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: buildPixivApiHeaders(
            accessToken: accessToken,
            acceptLanguage: acceptLanguage,
          ),
        ),
      );

      return _extractBody(response.data);
    } on DioException catch (e) {
      throw _translateDioException(e);
    }
  }

  static int _offsetFor(int page) {
    final effectivePage = page < 1 ? 1 : page;
    return (effectivePage - 1) * kPixivPageSize;
  }

  static String? _formatDate(DateTime? date) {
    if (date == null) return null;

    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
  }
}

/// Decodes [data] (a JSON string or an already-decoded map) and raises when
/// it carries an `{"error": ...}` envelope — the API can return this WITH an
/// HTTP 200, so status alone is never trusted.
Map<String, dynamic> _extractBody(dynamic data) {
  final decoded = switch (data) {
    final String s when s.isNotEmpty => jsonDecode(s),
    _ => data,
  };

  if (decoded is! Map<String, dynamic>) return const {};

  final error = decoded['error'];
  if (error != null) {
    throw _errorToException(error);
  }

  return decoded;
}

PixivException _translateDioException(DioException e) {
  final data = e.response?.data;
  final decoded = switch (data) {
    final String s when s.isNotEmpty => _tryDecode(s),
    final Map<String, dynamic> m => m,
    _ => null,
  };

  final error = decoded?['error'];
  if (error != null) {
    return _errorToException(error);
  }

  if (e.response?.statusCode == 429) {
    return const PixivRateLimitException('Rate limited (HTTP 429)');
  }

  return PixivApiException(e.message ?? 'Request failed');
}

dynamic _tryDecode(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

PixivException _errorToException(dynamic error) {
  final message = switch (error) {
    final Map m =>
      (m['message'] ?? m['user_message'] ?? m.toString()).toString(),
    _ => error.toString(),
  };

  if (message.toLowerCase().contains('rate limit')) {
    return PixivRateLimitException(message);
  }

  return PixivApiException(message);
}
