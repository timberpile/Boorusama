import 'dart:math' as math;

import 'package:equatable/equatable.dart';

const _maxSafeInteger = 9007199254740991;

int? _integer(Object? value) => switch (value) {
  final int value when value >= 0 && value <= _maxSafeInteger => value,
  _ => null,
};
int _positive(Object? value, String field) {
  final number = _integer(value);
  if (number == null || number == 0) throw FormatException('Invalid $field');
  return number;
}

String? _string(Object? value) => value is String ? value : null;
Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a source JSON object');
  }
  return value;
}

String? _mediaId(Object? value) {
  final id = value is String
      ? value
      : value is int
      ? '$value'
      : null;
  return id != null && RegExp(r'^[1-9][0-9]*$').hasMatch(id) ? id : null;
}

List<int> _ids(Object? value) => List.unmodifiable([
  if (value is List)
    for (final id in value)
      if (_integer(id) case final number? when number > 0) number,
]);

/// Media ID selects a CDN directory; it never replaces the Gallery identity.
final class NhentaiGallerySummary {
  const NhentaiGallerySummary({
    required this.id,
    this.mediaId,
    this.englishTitle,
    this.japaneseTitle,
    this.thumbnailPath,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.pageCount,
    this.favoriteCount,
    this.tagIds = const [],
    this.tagIdCoverage = NhentaiTagCoverage.unknown,
    this.blacklisted,
  });
  factory NhentaiGallerySummary.fromJson(Map<String, dynamic> json) =>
      NhentaiGallerySummary(
        id: _positive(json['id'], 'Gallery ID'),
        mediaId: _mediaId(json['media_id']),
        englishTitle: _string(json['english_title']),
        japaneseTitle: _string(json['japanese_title']),
        thumbnailPath: _string(json['thumbnail']),
        thumbnailWidth: _integer(json['thumbnail_width']),
        thumbnailHeight: _integer(json['thumbnail_height']),
        pageCount: _integer(json['num_pages']),
        favoriteCount: _integer(json['num_favorites']),
        tagIds: _ids(json['tag_ids']),
        tagIdCoverage: json['tag_ids'] is! List
            ? NhentaiTagCoverage.unknown
            : _ids(json['tag_ids']).length == (json['tag_ids'] as List).length
            ? NhentaiTagCoverage.complete
            : NhentaiTagCoverage.partial,
        blacklisted: json['blacklisted'] is bool
            ? json['blacklisted'] as bool
            : null,
      );
  final int id;
  final String? mediaId;
  final String? englishTitle;
  final String? japaneseTitle;
  final String? thumbnailPath;
  final int? thumbnailWidth;
  final int? thumbnailHeight;
  final int? pageCount;
  final int? favoriteCount;
  final List<int> tagIds;
  final NhentaiTagCoverage tagIdCoverage;
  final bool? blacklisted;
  String get sourceKey => 'gallery:$id';
}

final class NhentaiImageDescriptor {
  const NhentaiImageDescriptor({this.path, this.width, this.height});
  factory NhentaiImageDescriptor.fromJson(Map<String, dynamic> json) =>
      NhentaiImageDescriptor(
        path: _string(json['path']),
        width: _integer(json['width']),
        height: _integer(json['height']),
      );
  final String? path;
  final int? width;
  final int? height;
}

final class NhentaiPage {
  const NhentaiPage({
    required this.number,
    this.path,
    this.width,
    this.height,
    this.thumbnailPath,
    this.thumbnailWidth,
    this.thumbnailHeight,
  });
  factory NhentaiPage.fromJson(Map<String, dynamic> json) => NhentaiPage(
    number: _positive(json['number'], 'source Page number'),
    path: _string(json['path']),
    width: _integer(json['width']),
    height: _integer(json['height']),
    thumbnailPath: _string(json['thumbnail']),
    thumbnailWidth: _integer(json['thumbnail_width']),
    thumbnailHeight: _integer(json['thumbnail_height']),
  );
  final int number;
  final String? path;
  final int? width;
  final int? height;
  final String? thumbnailPath;
  final int? thumbnailWidth;
  final int? thumbnailHeight;
  int get sourcePosition => number - 1;
}

final class NhentaiTag extends Equatable {
  const NhentaiTag({
    required this.id,
    required this.type,
    required this.name,
    this.count,
    this.slug,
  });
  factory NhentaiTag.fromJson(Map<String, dynamic> json) {
    final type = _string(json['type']);
    final name = _string(json['name']);
    if (type == null || type.isEmpty || name == null || name.isEmpty) {
      throw const FormatException('Invalid tag identity');
    }
    return NhentaiTag(
      id: _positive(json['id'], 'tag ID'),
      type: type,
      name: name,
      count: _integer(json['count']),
      slug: _string(json['slug']),
    );
  }
  final int id;

  /// Preserve unknown source categories instead of relabeling them as `tag`.
  final String type;
  final String name;
  final int? count;
  final String? slug;
  @override
  List<Object?> get props => [id, type, name, count, slug];
}

enum NhentaiTagCoverage { unknown, partial, complete }

final class NhentaiGalleryDetails {
  NhentaiGalleryDetails._({
    required this.id,
    required this.mediaId,
    required this.englishTitle,
    required this.japaneseTitle,
    required this.pageCount,
    required this.favoriteCount,
    required this.uploadedAt,
    required this.tags,
    required this.tagCoverage,
    required this.pages,
    required this.cover,
    required this.thumbnail,
  });
  factory NhentaiGalleryDetails.fromJson(Map<String, dynamic> json) {
    final (tags, tagCoverage) = _parseTags(json['tags']);
    final title = json['title'] is Map<String, dynamic>
        ? json['title'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawPages = json['pages'];
    final pages = rawPages is List
        ? [for (final page in rawPages) NhentaiPage.fromJson(jsonObject(page))]
        : null;
    if (pages != null &&
        pages.map((page) => page.number).toSet().length != pages.length) {
      throw const FormatException('Duplicate source Page number');
    }
    final seconds = _integer(json['upload_date']);
    return NhentaiGalleryDetails._(
      id: _positive(json['id'], 'Gallery ID'),
      mediaId: _mediaId(json['media_id']),
      englishTitle: _string(title['english']),
      japaneseTitle: _string(title['japanese']),
      pageCount: _integer(json['num_pages']),
      favoriteCount: _integer(json['num_favorites']),
      uploadedAt: seconds == null || seconds > 8640000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      tags: tags,
      tagCoverage: tagCoverage,
      pages: pages == null ? null : List.unmodifiable(pages),
      cover: json['cover'] is Map<String, dynamic>
          ? NhentaiImageDescriptor.fromJson(
              json['cover'] as Map<String, dynamic>,
            )
          : null,
      thumbnail: json['thumbnail'] is Map<String, dynamic>
          ? NhentaiImageDescriptor.fromJson(
              json['thumbnail'] as Map<String, dynamic>,
            )
          : null,
    );
  }
  final int id;
  final String? mediaId;
  final String? englishTitle;
  final String? japaneseTitle;
  final int? pageCount;
  final int? favoriteCount;
  final DateTime? uploadedAt;
  final List<NhentaiTag> tags;

  /// Absent/null/non-list fields are unknown, rather than an observed empty
  /// membership. Malformed entries retain the usable subset as partial.
  final NhentaiTagCoverage tagCoverage;

  /// Null means absent, and an empty default array does not prove an empty Gallery.
  final List<NhentaiPage>? pages;
  final NhentaiImageDescriptor? cover;
  final NhentaiImageDescriptor? thumbnail;
  String get sourceKey => 'gallery:$id';
  bool get hasCompleteManifest =>
      pageCount != null &&
      pages != null &&
      pages!.length == pageCount &&
      pages!.every((p) => p.number <= pageCount!);

  static (List<NhentaiTag>, NhentaiTagCoverage) _parseTags(Object? value) {
    if (value is! List) return (const [], NhentaiTagCoverage.unknown);
    var coverage = NhentaiTagCoverage.complete;
    final tags = <NhentaiTag>[];
    for (final item in value) {
      try {
        tags.add(NhentaiTag.fromJson(jsonObject(item)));
      } on FormatException {
        coverage = NhentaiTagCoverage.partial;
      }
    }
    return (List.unmodifiable(tags), coverage);
  }
}

/// Raw length and server metadata remain separate from visible/deduplicated data.
final class NhentaiResultPage<T> {
  const NhentaiResultPage({
    required this.items,
    required this.page,
    this.total,
    this.pageCount,
    this.reportedPerPage,
  });
  factory NhentaiResultPage.fromJson(
    Map<String, dynamic> json, {
    required int page,
    required T Function(Map<String, dynamic>) parse,
  }) {
    final result = json['result'];
    if (result is! List) {
      throw const FormatException('Missing source result array');
    }
    return NhentaiResultPage(
      items: List.unmodifiable([
        for (final item in result) parse(jsonObject(item)),
      ]),
      page: _positive(page, 'page'),
      total: _integer(json['total']),
      pageCount: _integer(json['num_pages']),
      reportedPerPage: _integer(json['per_page']),
    );
  }
  final List<T> items;
  final int page;
  final int? total;
  final int? pageCount;
  final int? reportedPerPage;
  int get rawCount => items.length;
  bool? get hasMore => pageCount == null ? null : page < pageCount!;
}

/// Stable source key plus a bounded, collision-free bridge for numeric consumers.
/// The pairing, unlike a fixed multiplier, cannot collide when Page counts grow.
final class NhentaiPageIdentity extends Equatable {
  NhentaiPageIdentity({required this.galleryId, required this.pageNumber}) {
    _positive(galleryId, 'Gallery ID');
    _positive(pageNumber, 'source Page number');
    if (galleryId - 1 + pageNumber - 1 > 134217726) {
      throw const FormatException(
        'Page identity exceeds exact numeric storage',
      );
    }
  }
  factory NhentaiPageIdentity.parse(String key) {
    final match = RegExp(
      r'^gallery-page:([1-9][0-9]*):([1-9][0-9]*)$',
    ).firstMatch(key);
    if (match == null) throw const FormatException('Invalid Gallery Page key');
    return NhentaiPageIdentity(
      galleryId: int.parse(match[1]!),
      pageNumber: int.parse(match[2]!),
    );
  }
  factory NhentaiPageIdentity.fromNumericPostId(int id) {
    _positive(id, 'numeric Page ID');
    final value = id - 1;
    var diagonal = ((math.sqrt(8 * value + 1) - 1) / 2).floor();
    // Correct floating-point rounding at the exact-integer storage boundary.
    while (diagonal * (diagonal + 1) ~/ 2 > value) {
      diagonal--;
    }
    while ((diagonal + 1) * (diagonal + 2) ~/ 2 <= value) {
      diagonal++;
    }
    final pageIndex = value - diagonal * (diagonal + 1) ~/ 2;
    return NhentaiPageIdentity(
      galleryId: diagonal - pageIndex + 1,
      pageNumber: pageIndex + 1,
    );
  }
  final int galleryId;
  final int pageNumber;
  String get sourceKey => 'gallery-page:$galleryId:$pageNumber';
  int get sourcePosition => pageNumber - 1;
  int get numericPostId {
    final sum = galleryId - 1 + pageNumber - 1;
    return (sum * (sum + 1) ~/ 2) + pageNumber;
  }

  @override
  List<Object?> get props => [galleryId, pageNumber];
}
