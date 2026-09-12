import 'pixiv_illust_user_dto.dart';
import 'pixiv_image_urls_dto.dart';
import 'pixiv_series_dto.dart';
import 'pixiv_tag_dto.dart';

/// An illust/manga/ugoira work.
///
/// Every field is nullable — Pixiv keeps adding undocumented fields
/// (`restriction_attributes`, `seasonal_effect_animation_urls`,
/// `event_banners`, `is_accept_request`, ...) and this must keep parsing
/// without throwing when they appear or when documented ones go missing.
class PixivIllustDto {
  const PixivIllustDto({
    this.id,
    this.title,
    this.type,
    this.imageUrls,
    this.caption,
    this.restrict,
    this.user,
    this.tags = const [],
    this.tools = const [],
    this.createDate,
    this.pageCount,
    this.width,
    this.height,
    this.sanityLevel,
    this.xRestrict,
    this.series,
    this.metaSinglePage,
    this.metaPages = const [],
    this.totalView,
    this.totalBookmarks,
    this.isBookmarked,
    this.visible,
    this.isMuted,
    this.illustAiType,
  });

  factory PixivIllustDto.fromJson(Map<String, dynamic> json) {
    return PixivIllustDto(
      id: json['id'] as int?,
      title: json['title'] as String?,
      type: json['type'] as String?,
      imageUrls: PixivImageUrls.fromJson(
        json['image_urls'] as Map<String, dynamic>?,
      ),
      caption: json['caption'] as String?,
      restrict: json['restrict'] as int?,
      user: PixivIllustUser.fromJson(json['user'] as Map<String, dynamic>?),
      tags: _parseTags(json['tags']),
      tools: _parseStringList(json['tools']),
      createDate: json['create_date'] as String?,
      pageCount: json['page_count'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      sanityLevel: json['sanity_level'] as int?,
      xRestrict: json['x_restrict'] as int?,
      series: PixivSeries.fromJsonOrNull(
        json['series'] as Map<String, dynamic>?,
      ),
      metaSinglePage: PixivMetaSinglePage.fromJson(
        json['meta_single_page'] as Map<String, dynamic>?,
      ),
      metaPages: _parseMetaPages(json['meta_pages']),
      totalView: json['total_view'] as int?,
      totalBookmarks: json['total_bookmarks'] as int?,
      isBookmarked: json['is_bookmarked'] as bool?,
      visible: json['visible'] as bool?,
      isMuted: json['is_muted'] as bool?,
      illustAiType: json['illust_ai_type'] as int?,
    );
  }

  final int? id;
  final String? title;

  /// One of `illust`, `manga`, `ugoira`.
  final String? type;

  /// The illust's own preview URLs. Has NO `original` key — use
  /// [originalImageUrls] for full-resolution URLs.
  final PixivImageUrls? imageUrls;
  final String? caption;

  /// Publication visibility (e.g. public/private). NOT an age rating — see
  /// [xRestrict] and [sanityLevel] for that.
  final int? restrict;
  final PixivIllustUser? user;
  final List<PixivTag> tags;
  final List<String> tools;

  /// ISO8601 with a `+09:00` (JST) offset.
  final String? createDate;
  final int? pageCount;
  final int? width;
  final int? height;

  /// 0/2/4/6, increasing with explicitness.
  final int? sanityLevel;

  /// 0 = none, 1 = R18, 2 = R18G.
  final int? xRestrict;
  final PixivSeries? series;

  /// Present only when [pageCount] == 1.
  final PixivMetaSinglePage? metaSinglePage;

  /// Present only when [pageCount] > 1, one entry per page in order.
  final List<PixivMetaPage> metaPages;
  final int? totalView;
  final int? totalBookmarks;
  final bool? isBookmarked;
  final bool? visible;
  final bool? isMuted;

  /// 0 = unspecified/not-AI, 1 = not AI-generated, 2 = AI-generated.
  final int? illustAiType;

  /// Ordered original-resolution URLs for every page.
  ///
  /// - `pageCount == 1` reads [metaSinglePage.originalImageUrl].
  /// - `pageCount > 1` reads each [metaPages] entry's
  ///   `imageUrls.original`, in order.
  ///
  /// The top-level [imageUrls] never carries an `original` URL, so it is
  /// never consulted here.
  List<String> get originalImageUrls {
    if (pageCount != null && pageCount! > 1) {
      return metaPages
          .map((p) => p.imageUrls?.original)
          .whereType<String>()
          .toList();
    }

    final single = metaSinglePage?.originalImageUrl;
    return single != null ? [single] : const [];
  }

  static List<PixivTag> _parseTags(dynamic json) {
    if (json is! List) return const [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(PixivTag.fromJson)
        .toList();
  }

  static List<String> _parseStringList(dynamic json) {
    if (json is! List) return const [];

    return json.whereType<String>().toList();
  }

  static List<PixivMetaPage> _parseMetaPages(dynamic json) {
    if (json is! List) return const [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(PixivMetaPage.fromJson)
        .toList();
  }
}
