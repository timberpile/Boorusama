part of 'pixiv_client.dart';

const _relatedPath = '/v2/illust/related';
final _relatedArrayKey = RegExp(r'^(seed_illust_ids|viewed)\[[0-9]+\]$');
final _relatedPositiveId = RegExp(r'^[1-9][0-9]*$');
final _relatedOffset = RegExp(r'^[0-9]+$');

/// A continuation belongs to one artwork and carries only Pixiv query data.
final class PixivRelatedCursor {
  PixivRelatedCursor._(this._illustId, Map<String, String> parameters)
    : _query = Uri(queryParameters: parameters);

  final int _illustId;
  final Uri _query;

  static PixivRelatedCursor? _parse(Object? value, int illustId) {
    if (value == null || value == '') return null;
    final url = value is String ? Uri.tryParse(value) : null;
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.origin != kPixivApiBaseUrl ||
        url.userInfo.isNotEmpty ||
        url.path != _relatedPath ||
        url.hasFragment) {
      throw const FormatException('Invalid Pixiv related continuation URL');
    }
    final parameters = url.queryParametersAll;
    final sortedKeys = parameters.keys.toList()..sort();
    final query = <String, String>{};
    for (final key in sortedKeys) {
      final values = parameters[key]!;
      if (values.length != 1) {
        throw const FormatException('Repeated Pixiv related query parameter');
      }
      final value = values.single;
      final valid = switch (key) {
        'illust_id' => value == '$illustId',
        'filter' => value == _kFilter,
        'offset' => _relatedOffset.hasMatch(value),
        _ =>
          _relatedArrayKey.hasMatch(key) && _relatedPositiveId.hasMatch(value),
      };
      if (!valid) {
        throw const FormatException('Invalid Pixiv related query parameter');
      }
      query[key] = value;
    }
    if (!query.containsKey('illust_id') || !query.containsKey('filter')) {
      throw const FormatException('Missing Pixiv related continuation scope');
    }
    return PixivRelatedCursor._(illustId, query);
  }

  @override
  bool operator ==(Object other) =>
      other is PixivRelatedCursor && _query == other._query;

  @override
  int get hashCode => _query.hashCode;
}

final class PixivRelatedPage {
  const PixivRelatedPage(this.illusts, {this.nextCursor});

  final List<PixivIllustDto> illusts;
  final PixivRelatedCursor? nextCursor;
}

extension PixivRelatedApi on PixivClient {
  /// Pixiv continuation lists can contain indexed seed and viewed IDs.
  /// Rebuild the request against the fixed endpoint under the current account.
  Future<PixivRelatedPage> getRelatedIllusts({
    required int illustId,
    PixivRelatedCursor? cursor,
    CancelToken? cancelToken,
  }) async {
    if (illustId <= 0 || (cursor != null && cursor._illustId != illustId)) {
      throw ArgumentError.value(illustId, 'illustId');
    }
    final body = await _get(
      _relatedPath,
      queryParameters:
          cursor?._query.queryParameters ??
          {'illust_id': illustId, 'filter': _kFilter},
      cancelToken: cancelToken,
      followRedirects: false,
    );
    if (body['illusts'] is! List) {
      throw const FormatException('Invalid Pixiv related artwork response');
    }
    return PixivRelatedPage(
      PixivIllustListResult.fromJson(body).illusts,
      nextCursor: PixivRelatedCursor._parse(body['next_url'], illustId),
    );
  }
}
