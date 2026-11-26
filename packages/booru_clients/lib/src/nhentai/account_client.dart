import 'package:dio/dio.dart';

import 'client.dart';
import 'models.dart';

/// Use an isolated transport that validates the final destination before
/// adding the API key. This client never shares a transport with public media.
final class NhentaiAccountClient {
  NhentaiAccountClient({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    CancelToken? cancelToken, {
    Map<String, String>? query,
  }) async {
    final uri = NhentaiClient.site.resolve(path);
    final response = await _dio.requestUri<Object?>(
      query == null ? uri : uri.replace(queryParameters: query),
      options: Options(
        method: method,
        followRedirects: false,
        headers: {'Accept': 'application/json'},
      ),
      cancelToken: cancelToken,
    );
    return jsonObject(response.data);
  }

  Future<({int id, String username})> getAccount({
    CancelToken? cancelToken,
  }) async {
    final account = await _request('GET', '/api/v2/user', cancelToken);
    if (account case {
      'id': final int id,
      'username': final String name,
    } when id > 0 && name.trim().isNotEmpty) {
      return (id: id, username: name);
    }
    throw const FormatException('Invalid nhentai account');
  }

  Future<NhentaiResultPage<NhentaiGallerySummary>> getFavorites(
    int page, {
    CancelToken? cancelToken,
  }) async {
    if (page < 1) throw ArgumentError('Invalid favorites page');
    return NhentaiResultPage.fromJson(
      await _request(
        'GET',
        '/api/v2/favorites',
        cancelToken,
        query: {'page': '$page'},
      ),
      page: page,
      parse: NhentaiGallerySummary.fromJson,
    );
  }

  Future<bool> setFavorite(
    int id,
    bool favorited, {
    CancelToken? cancelToken,
  }) => _favorite(favorited ? 'POST' : 'DELETE', id, cancelToken);

  Future<bool> _favorite(
    String method,
    int id,
    CancelToken? cancelToken,
  ) async {
    final data = await _request(
      method,
      '/api/v2/galleries/${nhentaiGalleryId(id)}/favorite',
      cancelToken,
    );
    if (data['favorited'] case final bool value) return value;
    throw const FormatException('Invalid nhentai favorite status');
  }
}
