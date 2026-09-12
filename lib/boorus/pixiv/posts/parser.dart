// Package imports:
import 'package:booru_clients/pixiv.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import 'types.dart';

/// Upper bound on pages per work used to keep synthetic ids collision-free.
///
/// Works with more pages than this fall back to the hashed id path. Pixiv
/// caps manga/illust uploads at 200 pages, so this leaves ample headroom.
const _kPageIndexSpace = 1000;

/// Basenames Pixiv serves from `s.pximg.net` instead of the real artwork for
/// gated/restricted works — see [PixivPost.isRestricted].
const _kPlaceholderBasenames = <String>{
  'limit_sanity_level_360.png',
  'limit_unviewable_360.png',
  'limit_mypixiv_360.png',
};

/// Flattens one illust into one [PixivPost] per page.
///
/// Returns an empty list when the illust is missing an id/author, is hidden
/// (`visible == false` or `is_muted == true`), or has no resolvable original
/// image URL.
List<PixivPost> illustDtoToPosts(
  PixivIllustDto dto, {
  PostMetadata? metadata,
}) {
  final illustId = dto.id;
  final userId = dto.user?.id;

  if (illustId == null || userId == null) return const [];
  if (!(dto.visible ?? true) || (dto.isMuted ?? false)) return const [];

  final originals = dto.originalImageUrls;
  if (originals.isEmpty) return const [];

  final pageCount = originals.length;
  final createdAt = _parseDate(dto.createDate);
  final rating = pixivRatingFrom(
    xRestrict: dto.xRestrict,
    sanityLevel: dto.sanityLevel,
  );
  final tags = _tagsFrom(dto.tags);
  final illustType = PixivIllustType.parse(dto.type);
  final userName = dto.user?.name ?? '';
  final userAccount = dto.user?.account ?? '';

  return [
    for (final (index, original) in originals.indexed)
      _toPost(
        dto: dto,
        illustId: illustId,
        userId: userId,
        userName: userName,
        userAccount: userAccount,
        pageIndex: index,
        pageCount: pageCount,
        original: original,
        createdAt: createdAt,
        rating: rating,
        tags: tags,
        illustType: illustType,
        metadata: metadata,
      ),
  ];
}

/// Flattens a page of illusts, preserving order.
List<PixivPost> illustDtosToPosts(
  List<PixivIllustDto> dtos, {
  PostMetadata? metadata,
}) => [
  for (final dto in dtos) ...illustDtoToPosts(dto, metadata: metadata),
];

PixivPost _toPost({
  required PixivIllustDto dto,
  required int illustId,
  required int userId,
  required String userName,
  required String userAccount,
  required int pageIndex,
  required int pageCount,
  required String original,
  required DateTime? createdAt,
  required Rating rating,
  required Set<String> tags,
  required PixivIllustType illustType,
  required PostMetadata? metadata,
}) {
  final thumbnailUrl = _thumbnailFor(
    dto,
    pageIndex,
    sample: false,
    original: original,
  );
  final sampleUrl = _sampleFor(
    dto,
    pageIndex,
    original: original,
  );
  final format = extensionOf(original);
  final isRestricted = _isPlaceholder(original);

  return PixivPost(
    id: syntheticPostId(illustId: illustId, pageIndex: pageIndex),
    thumbnailImageUrl: thumbnailUrl,
    sampleImageUrl: sampleUrl,
    originalImageUrl: original,
    tags: tags,
    rating: rating,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: pageCount > 1,
    source: PostSource.none(),
    score: 0,
    duration: kNoduration,
    fileSize: 0,
    format: format,
    hasSound: false,
    height: (dto.height ?? 0).toDouble(),
    md5: '',
    videoThumbnailUrl: thumbnailUrl,
    videoUrl: '',
    width: (dto.width ?? 0).toDouble(),
    uploaderId: userId,
    uploaderName: userName,
    createdAt: createdAt,
    metadata: metadata,
    illustId: illustId,
    pageIndex: pageIndex,
    pageCount: pageCount,
    userId: userId,
    userName: userName,
    userAccount: userAccount,
    illustType: illustType,
    totalBookmarks: dto.totalBookmarks ?? 0,
    totalView: dto.totalView ?? 0,
    aiType: dto.illustAiType ?? 0,
    seriesTitle: dto.series?.title,
    isUgoira: illustType == PixivIllustType.ugoira,
    isRestricted: isRestricted,
  );
}

/// Resolves the thumbnail (`square_medium`) URL for one page.
///
/// Page 0 reads the illust's own `image_urls`. Later pages read their own
/// `meta_pages` entry — Pixiv does not always populate per-page thumbnails
/// there, so an unavailable one falls back to the original image rather than
/// rendering an empty preview.
String _thumbnailFor(
  PixivIllustDto dto,
  int pageIndex, {
  required bool sample,
  required String original,
}) {
  if (pageIndex == 0) {
    final top = sample ? dto.imageUrls?.medium : dto.imageUrls?.squareMedium;
    if (top != null) return top;
  }

  final page = pageIndex < dto.metaPages.length
      ? dto.metaPages[pageIndex]
      : null;
  final fromPage = sample
      ? page?.imageUrls?.medium
      : page?.imageUrls?.squareMedium;

  return fromPage ?? original;
}

/// Resolves the sample (details view) URL for one page, preferring the
/// `large` variant (1200px long side, q90) over `medium` (540px box, q70) —
/// `medium` is sized for grid thumbnails and looks artefacted full-screen.
///
/// Page 0 reads the illust's own `image_urls`. Later pages read their own
/// `meta_pages` entry, falling back to the original image when neither
/// `large` nor `medium` is available.
String _sampleFor(
  PixivIllustDto dto,
  int pageIndex, {
  required String original,
}) {
  if (pageIndex == 0) {
    final top = dto.imageUrls?.large ?? dto.imageUrls?.medium;
    if (top != null) return top;
  }

  final page = pageIndex < dto.metaPages.length
      ? dto.metaPages[pageIndex]
      : null;
  final fromPage = page?.imageUrls?.large ?? page?.imageUrls?.medium;

  return fromPage ?? original;
}

Set<String> _tagsFrom(List<PixivTag> tags) {
  final result = <String>{};

  for (final tag in tags) {
    final name = tag.name;
    if (name != null && name.isNotEmpty) {
      result.add(name);
    }

    final translated = tag.translatedName;
    if (translated != null && translated.isNotEmpty && translated != name) {
      result.add(translated);
    }
  }

  return result;
}

bool _isPlaceholder(String url) {
  final uri = Uri.tryParse(url);
  final basename = uri != null && uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : '';

  return _kPlaceholderBasenames.contains(basename);
}

/// Maps Pixiv's two independent explicitness signals onto [Rating].
///
/// `x_restrict` is checked first since it is the more authoritative signal
/// (R18/R18G classification); `sanity_level` fills in the rest. A
/// `sanity_level` of 0-2 only counts as [Rating.general] when `x_restrict`
/// confirms the work is unrestricted — an unknown `x_restrict` is not
/// treated as safe.
Rating pixivRatingFrom({
  required int? xRestrict,
  required int? sanityLevel,
}) {
  if (xRestrict == 1 || xRestrict == 2) return Rating.explicit;
  if (sanityLevel != null && sanityLevel >= 6) return Rating.explicit;
  if (sanityLevel == 4) return Rating.questionable;
  if (sanityLevel != null && sanityLevel <= 2 && xRestrict == 0) {
    return Rating.general;
  }

  return Rating.unknown;
}

/// A unique, stable id for one page of one work.
///
/// [Post.id] is an `int` and [SimplePost] compares by it alone, while the grid
/// both dedupes on it and uses it as a widget key. Pages of the same work
/// must therefore not share an id. Ids also outlive the session because
/// bookmarks persist them, so this has to be deterministic — no `hashCode`.
///
/// Real illust ids get room reserved for their page index. Anything outside
/// that (shouldn't happen for a real illust id, but kept as a safety net)
/// falls back to a hash of the composite key.
int syntheticPostId({
  required int illustId,
  required int pageIndex,
}) {
  if (illustId > 0 && pageIndex < _kPageIndexSpace) {
    return illustId * _kPageIndexSpace + pageIndex;
  }

  return _stableHash('$illustId#$pageIndex');
}

/// FNV-1a, 32-bit. Deterministic across runs and releases, unlike
/// `Object.hash`, which is what makes it safe for persisted ids.
int _stableHash(String value) {
  var hash = 0x811c9dc5;

  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }

  // Keep clear of the numeric-id space so the two schemes cannot collide.
  return hash | 0x40000000;
}

/// `.../abc123_p0.jpg` -> `jpg`. Empty when there is no extension.
String extensionOf(String url) {
  final uri = Uri.tryParse(url);
  final path = uri?.path ?? url;
  final lastSlash = path.lastIndexOf('/');
  final name = lastSlash == -1 ? path : path.substring(lastSlash + 1);
  final dot = name.lastIndexOf('.');

  if (dot == -1 || dot == name.length - 1) return '';

  return name.substring(dot + 1).toLowerCase();
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;

  return DateTime.tryParse(value);
}
