import '../http/request_interruption.dart';
// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

// Project imports:
import 'autocomplete.dart';
import 'types/types.dart';

const _kZerochanUrl = 'https://www.zerochan.net';
const kZerochanMinPageLimit = 1;
const kZerochanMaxPageLimit = 250;

class ZerochanClient {
  ZerochanClient({
    Dio? dio,
    String? baseUrl,
    this.logger,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? _kZerochanUrl,
               headers: {
                 'User-Agent': 'My test client - anon',
               },
             ),
           ) {
    final configuredBaseUrl = baseUrl ?? _dio.options.baseUrl;
    _baseUrl = configuredBaseUrl.isNotEmpty ? configuredBaseUrl : _kZerochanUrl;

    if (_dio.options.baseUrl.isEmpty) {
      _dio.options = _dio.options.copyWith(baseUrl: _baseUrl);
    }
  }

  final Dio _dio;
  late final String _baseUrl;
  final void Function(String message)? logger;

  /// Input tag must be in snake case
  /// Sort is only available when tags is not null or empty
  Future<List<PostDto>> getPosts({
    List<String>? tags,
    int? page,
    int? limit,
    ZerochanSortOrder? sort,
    bool strict = false,
  }) async {
    final tagString =
        tags
            ?.map((e) => e.replaceAll('_', ' '))
            .map((e) => e.replaceAll(' ', '+'))
            .join(',') ??
        '';

    final l = _clampPageLimit(limit);

    try {
      final response = await _dio.get(
        '/$tagString?json',
        queryParameters: {
          'p': ?page,
          'l': ?l,
          if (sort != null && (tags != null && tags.isNotEmpty))
            's': sort.queryParam,
        },
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      return _readItems(response.data);
    } on DioException catch (error) {
      if (isDataRequestInterruption(error) ||
          error.response?.statusCode != 500) {
        rethrow;
      }
      try {
        return _logRecovered(_readItems(error.response?.data), 500);
      } on FormatException {
        throw error;
      }
    }
  }

  List<PostDto> _logRecovered(List<PostDto> items, int? statusCode) {
    logger?.call(
      'Recovered ${items.length} posts from a malformed response '
      '(status $statusCode)',
    );
    return items;
  }

  Future<PostDto?> getPost({
    required int id,
  }) async {
    final response = await _dio.get(
      '/$id?json',
      options: Options(
        responseType: ResponseType.plain,
      ),
    );

    final data = response.data;
    final json = data is String ? jsonDecode(data) : data;

    if (json is! Map) {
      throw const FormatException('Zerochan detail response is not an object');
    }

    if (json.isEmpty) return null;

    return PostDto.fromJson(Map<String, dynamic>.from(json));
  }

  /// Resolves the explicit media URLs needed for a download.
  ///
  /// Asiachan currently serves a broken detail JSON response, so it uses the
  /// post page directly. Zerochan uses its detail API and only falls back to
  /// the post page when the API does not provide a usable original URL.
  Future<ZerochanDownloadUrls?> getDownloadUrls(int postId) async {
    try {
      if (_isAsiachan) {
        return await _getDownloadUrlsFromHtml(postId);
      }

      PostDto? detail;
      try {
        detail = await getPost(id: postId);
      } on FormatException {
        // Some post detail responses are malformed. The normal post page is
        // a compatible fallback for those responses.
      } on TypeError {
        // Treat an invalid detail shape like malformed JSON.
      }

      final apiUrls = _downloadUrlsFromPost(detail, postId);
      if (apiUrls?.full case final full? when full.isNotEmpty) {
        return apiUrls;
      }

      final htmlUrls = await _getDownloadUrlsFromHtml(postId);
      return _mergeDownloadUrls(apiUrls, htmlUrls);
    } on DioException catch (error) {
      if (error.response?.statusCode case final status?
          when status == 404 || status == 410) {
        return null;
      }

      rethrow;
    }
  }

  Future<List<TagDto>> getTagsFromPostId({
    required int postId,
  }) async {
    final response = await _dio.get(
      '$postId',
      options: Options(
        responseType: ResponseType.plain,
      ),
    );

    final data = response.data;

    // use flutter_html to parse the html
    final document = parse(data);

    // query id 'tags' to get the tags
    final tags = document.getElementById('tags');

    if (tags == null) return [];

    // get all the li tags inside the tags id
    final tagElements = tags.getElementsByTagName('li');

    return tagElements.map((e) => TagDto.fromHtmlElement(e)).toList();
  }

  Future<List<AutocompleteDto>> getAutocomplete({
    required String query,
  }) async {
    final response = await _dio.get(
      '/suggest?json',
      queryParameters: {
        'q': query,
      },
      options: Options(
        responseType: ResponseType.plain,
      ),
    );

    final data = response.data;

    return parseAutocomplete(data);
  }

  bool get _isAsiachan {
    final host = Uri.tryParse(_baseUrl)?.host.toLowerCase() ?? '';
    return host == 'asiachan.com' || host.endsWith('.asiachan.com');
  }

  Future<ZerochanDownloadUrls?> _getDownloadUrlsFromHtml(int postId) async {
    final response = await _dio.get(
      '/$postId',
      options: Options(
        responseType: ResponseType.plain,
      ),
    );

    final document = parse(response.data?.toString() ?? '');
    final pageUri = _postUri(postId);
    final anchorUrl = document
        .querySelector('#large a.preview[href]')
        ?.attributes['href'];
    final fullUrl = _resolveHttpUrl(anchorUrl, pageUri);

    if (fullUrl != null) {
      return ZerochanDownloadUrls(full: fullUrl);
    }

    for (final meta in document.querySelectorAll('meta')) {
      final property = meta.attributes['property']?.toLowerCase();
      final name = meta.attributes['name']?.toLowerCase();
      if (property != 'og:image' && name != 'og:image') continue;

      final url = _resolveHttpUrl(meta.attributes['content'], pageUri);
      if (url != null && _looksLikePostFullImage(url, postId)) {
        return ZerochanDownloadUrls(full: url);
      }
    }

    return null;
  }

  ZerochanDownloadUrls? _downloadUrlsFromPost(PostDto? post, int postId) {
    if (post == null) return null;

    final pageUri = _postUri(postId);
    final urls = ZerochanDownloadUrls(
      full: _resolveHttpUrl(post.full, pageUri),
      large: _resolveHttpUrl(post.large, pageUri),
      medium: _resolveHttpUrl(post.medium, pageUri),
      small: _resolveHttpUrl(post.small, pageUri),
    );

    return urls.isUseful ? urls : null;
  }

  ZerochanDownloadUrls? _mergeDownloadUrls(
    ZerochanDownloadUrls? first,
    ZerochanDownloadUrls? second,
  ) {
    final merged = ZerochanDownloadUrls(
      full: first?.full ?? second?.full,
      large: first?.large ?? second?.large,
      medium: first?.medium ?? second?.medium,
      small: first?.small ?? second?.small,
    );

    return merged.isUseful ? merged : null;
  }

  Uri _postUri(int postId) {
    final baseUri = Uri.parse(_baseUrl);
    return baseUri.replace(
      path: '/$postId',
      query: null,
      fragment: null,
    );
  }
}

List<PostDto> _readItems(Object? data) {
  Object? decoded = data;
  if (data is String) {
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      final object = _extractItemsObject(data);
      if (object == null) rethrow;
      decoded = object;
    }
  }
  if (decoded case {'items': final List items}) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        final dto = PostDto.fromJson(item);
        if (dto.id != null) return dto;
      }
      throw const FormatException('Invalid Zerochan post');
    }).toList();
  }
  throw const FormatException('Invalid Zerochan list');
}

String? _resolveHttpUrl(String? rawUrl, Uri pageUri) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;

  final uri = pageUri.resolve(value);
  if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
    return null;
  }

  return uri.toString();
}

bool _looksLikePostFullImage(String url, int postId) {
  final path = Uri.parse(url).path.toLowerCase();
  return path.contains(postId.toString()) && path.contains('full');
}

// The live list endpoint sometimes prints an extra opening brace before the
// entire JSON object, followed by HTML. Two consecutive object starts cannot
// introduce a valid JSON member.
final _extraListBrace = RegExp(r'^\s*\{\s*(?=\{)');

// Some responses surround a complete list object with server warnings.
Map<String, dynamic>? _extractItemsObject(String body) {
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;
  final offset = _extraListBrace.matchAsPrefix(body)?.end ?? 0;
  for (var i = offset; i < body.length; i++) {
    final char = body[i];
    if (depth == 0) {
      if (char != '{') continue;
      start = i;
    }
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    switch (char) {
      case '"':
        inString = true;
      case '{' || '[':
        depth++;
      case '}' || ']':
        depth--;
        if (depth == 0) {
          try {
            final value = jsonDecode(body.substring(start, i + 1));
            if (value is Map<String, dynamic> && value.containsKey('items')) {
              return value;
            }
          } on FormatException {
            // Continue past balanced non-JSON text in the warning.
          }
        }
    }
  }

  return null;
}

int? _clampPageLimit(int? limit) {
  if (limit == null) return null;

  if (limit < kZerochanMinPageLimit) return kZerochanMinPageLimit;
  if (limit > kZerochanMaxPageLimit) return kZerochanMaxPageLimit;

  return limit;
}
