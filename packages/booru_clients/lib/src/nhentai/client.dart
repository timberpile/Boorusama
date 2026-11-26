import 'dart:convert';

import 'package:dio/dio.dart';

import 'media_policy.dart';
import 'models.dart';

enum NhentaiGallerySort {
  newest(null),
  popularToday('popular-today'),
  popularWeek('popular-week'),
  popularAllTime('popular');

  const NhentaiGallerySort(this.parameter);
  final String? parameter;
}

/// Read-only API wrapper. Supply the application's coordinated anonymous Dio;
/// the app's final transport adapter remains responsible for header/redirect safety.
final class NhentaiClient {
  static const tagTypes = {
    'tag',
    'artist',
    'character',
    'parody',
    'group',
    'language',
    'category',
  };
  static const tagSearchPath = '/api/v2/tags/search';
  static const tagSearchLimit = 10;
  static const tagSearchQueryLimit = 256;

  static bool acceptsTagSearch(Object? data) =>
      data is Map<String, dynamic> &&
      data.keys.every(const {'query', 'type', 'limit'}.contains) &&
      data['query'] is String &&
      (data['query'] as String).trim().isNotEmpty &&
      (data['query'] as String).length <= tagSearchQueryLimit &&
      (!data.containsKey('type') || tagTypes.contains(data['type'])) &&
      data['limit'] == tagSearchLimit;

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
    NhentaiGallerySort sort = NhentaiGallerySort.newest,
    CancelToken? cancelToken,
  }) async {
    _page(page, perPage);
    // The search endpoint accepts "*" for an unfiltered popularity listing.
    final search = query ?? (sort.parameter == null ? null : '*');
    return NhentaiResultPage.fromJson(
      jsonObject(
        await _get(
          search == null ? '/api/v2/galleries' : '/api/v2/search',
          query: {
            'page': '$page',
            if (search == null) 'per_page': '$perPage',
            'query': ?search,
            'sort': ?sort.parameter,
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

  Future<int> getRandomGalleryId({CancelToken? cancelToken}) async =>
      nhentaiGalleryId(
        jsonObject(
          await _get('/api/v2/galleries/random', cancelToken: cancelToken),
        )['id'],
      );

  Future<List<NhentaiGallerySummary>> getPopularGalleries({
    CancelToken? cancelToken,
  }) async => _parseGalleryList(
    await _get('/api/v2/galleries/popular', cancelToken: cancelToken),
  );

  Future<List<NhentaiGallerySummary>> getRelatedGalleries(
    int id, {
    CancelToken? cancelToken,
  }) async => _parseGalleryList(
    jsonObject(
      await _get(
        '/api/v2/galleries/${nhentaiGalleryId(id)}/related',
        cancelToken: cancelToken,
      ),
    )['result'],
  );

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

  Future<List<NhentaiTag>> searchTags(
    String prefix, {
    String? type,
    CancelToken? cancelToken,
  }) async {
    final data = {'query': prefix, 'type': ?type, 'limit': tagSearchLimit};
    if (!acceptsTagSearch(data)) throw ArgumentError('Invalid tag prefix');
    final response = await _dio.postUri<Object?>(
      site.resolve(tagSearchPath),
      data: jsonEncode(data),
      options: Options(
        followRedirects: false,
        contentType: Headers.jsonContentType,
        headers: {'Accept': 'application/json'},
      ),
      cancelToken: cancelToken,
    );
    final raw = response.data;
    if (raw is! List || raw.length > tagSearchLimit) {
      throw const FormatException('Invalid tag suggestion response');
    }
    final tags = [
      for (final item in raw) NhentaiTag.fromJson(jsonObject(item)),
    ];
    if (tags.any(
      (tag) =>
          !tagTypes.contains(tag.type) || (type != null && tag.type != type),
    )) {
      throw const FormatException('Foreign tag suggestion result');
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

int nhentaiGalleryId(Object? value) {
  if (value is! int || value < 1 || value > 9007199254740991) {
    throw const FormatException('Invalid Gallery ID');
  }
  return value;
}

List<NhentaiGallerySummary> _parseGalleryList(Object? data) {
  if (data is! List) throw const FormatException('Invalid Gallery list');
  return [
    for (final item in data) NhentaiGallerySummary.fromJson(jsonObject(item)),
  ];
}
