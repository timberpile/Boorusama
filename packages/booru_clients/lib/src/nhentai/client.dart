import 'package:dio/dio.dart';

import 'media_policy.dart';
import 'models.dart';

/// Read-only API wrapper. Supply the application's coordinated anonymous Dio;
/// the app's final transport adapter remains responsible for header/redirect safety.
/// This foundation is not registered as an application engine yet.
final class NhentaiClient {
  NhentaiClient({required Dio dio}) : _dio = dio;
  final Dio _dio;
  static final site = Uri.parse('https://nhentai.net');
  Future<Object?> _get(
    String path, {
    Map<String, dynamic> query = const {},
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.getUri<Object?>(
      site.resolve(path).replace(queryParameters: query.isEmpty ? null : query),
      options: Options(
        followRedirects: false,
        headers: {'Accept': 'application/json'},
      ),
      cancelToken: cancelToken,
    );
    return response.data;
  }

  void _page(int page, int limit) {
    if (page < 1 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid source page request');
    }
  }

  Future<NhentaiMediaPolicy> getMediaPolicy({CancelToken? cancelToken}) async =>
      NhentaiMediaPolicy.fromJson(
        jsonObject(await _get('/api/v2/config', cancelToken: cancelToken)),
      );
  Future<NhentaiResultPage<NhentaiGallerySummary>> getGalleries({
    int page = 1,
    int perPage = 25,
    String? query,
    CancelToken? cancelToken,
  }) async {
    _page(page, perPage);
    return NhentaiResultPage.fromJson(
      jsonObject(
        await _get(
          query == null ? '/api/v2/galleries' : '/api/v2/search',
          query: {
            'page': '$page',
            'per_page': '$perPage',
            'query': ?query,
          },
          cancelToken: cancelToken,
        ),
      ),
      page: page,
      parse: NhentaiGallerySummary.fromJson,
    );
  }

  Future<NhentaiGalleryDetails> getGallery(
    int id, {
    CancelToken? cancelToken,
  }) async {
    if (id < 1 || id > 9007199254740991) throw ArgumentError.value(id, 'id');
    final details = NhentaiGalleryDetails.fromJson(
      jsonObject(await _get('/api/v2/galleries/$id', cancelToken: cancelToken)),
    );
    if (details.id != id) {
      throw const FormatException('Foreign Gallery response');
    }
    return details;
  }

  Future<List<NhentaiTag>> getTagsByIds(
    Iterable<int> ids, {
    CancelToken? cancelToken,
  }) async {
    final requested = ids.toSet();
    if (requested.isEmpty) return const [];
    if (requested.length > 100 ||
        requested.any((id) => id < 1 || id > 9007199254740991)) {
      throw ArgumentError('Tag lookups require 1-100 positive IDs');
    }
    final raw = await _get(
      '/api/v2/tags/ids',
      query: {'ids': requested.join(',')},
      cancelToken: cancelToken,
    );
    if (raw is! List) {
      throw const FormatException('Invalid tag lookup response');
    }
    final tags = [for (final tag in raw) NhentaiTag.fromJson(jsonObject(tag))];
    if (tags.any((tag) => !requested.contains(tag.id))) {
      throw const FormatException('Foreign tag lookup result');
    }
    return tags;
  }

  Future<NhentaiResultPage<NhentaiTag>> getTagCatalog(
    String category, {
    int page = 1,
    int perPage = 100,
    String sort = 'popular',
    CancelToken? cancelToken,
  }) async {
    _page(page, perPage);
    if (!RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(category) ||
        category == 'general' ||
        !const ['popular', 'name'].contains(sort)) {
      throw ArgumentError('Invalid source tag catalog request');
    }
    final result = NhentaiResultPage.fromJson(
      jsonObject(
        await _get(
          '/api/v2/tags/$category',
          query: {
            'page': '$page',
            'per_page': '$perPage',
            'sort': sort,
          },
          cancelToken: cancelToken,
        ),
      ),
      page: page,
      parse: NhentaiTag.fromJson,
    );
    if (result.items.any((tag) => tag.type != category)) {
      throw const FormatException('Foreign tag category');
    }
    return result;
  }
}
