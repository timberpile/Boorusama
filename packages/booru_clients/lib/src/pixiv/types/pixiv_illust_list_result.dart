import 'pixiv_illust_dto.dart';

/// A single offset-paged batch of illusts.
///
/// [hasMore] only reflects whether the API's `next_url` was non-null — it is
/// deliberately NOT resolved or followed (that would be an SSRF surface;
/// offset paging makes it unnecessary since every page is independently
/// addressable via `offset = (page - 1) * 30`).
class PixivIllustListResult {
  const PixivIllustListResult({this.illusts = const [], this.hasMore = false});

  factory PixivIllustListResult.fromJson(Map<String, dynamic> json) {
    return PixivIllustListResult(
      illusts: _parseIllusts(json['illusts']),
      hasMore: json['next_url'] != null,
    );
  }

  final List<PixivIllustDto> illusts;
  final bool hasMore;

  static List<PixivIllustDto> _parseIllusts(dynamic json) {
    if (json is! List) return const [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(PixivIllustDto.fromJson)
        .toList();
  }
}
