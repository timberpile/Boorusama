// Project imports:
import '../../../core/posts/post/types.dart';

/// The kind of work an illust represents, mirroring the API's `type` string.
enum PixivIllustType {
  illust,
  manga,
  ugoira,
  unknown;

  factory PixivIllustType.parse(String? value) => switch (value) {
    'illust' => PixivIllustType.illust,
    'manga' => PixivIllustType.manga,
    'ugoira' => PixivIllustType.ugoira,
    _ => PixivIllustType.unknown,
  };
}

/// One page of one Pixiv illust.
///
/// A Pixiv work (illust) can carry several pages, but [Post] models exactly
/// one, so each page becomes its own [PixivPost]. [illustId] is therefore
/// shared between siblings while [id] is unique — see `syntheticPostId` in
/// `parser.dart` for why that matters.
class PixivPost extends SimplePost {
  PixivPost({
    required super.id,
    required super.thumbnailImageUrl,
    required super.sampleImageUrl,
    required super.originalImageUrl,
    required super.tags,
    required super.rating,
    required super.hasComment,
    required super.isTranslated,
    required super.hasParentOrChildren,
    required super.source,
    required super.score,
    required super.duration,
    required super.fileSize,
    required super.format,
    required super.hasSound,
    required super.height,
    required super.md5,
    required super.videoThumbnailUrl,
    required super.videoUrl,
    required super.width,
    required super.uploaderId,
    required super.metadata,
    required this.illustId,
    required this.pageIndex,
    required this.pageCount,
    required this.userId,
    required this.userName,
    required this.userAccount,
    required this.illustType,
    required this.totalBookmarks,
    required this.totalView,
    required this.aiType,
    required this.isUgoira,
    required this.isRestricted,
    this.seriesTitle,
    super.createdAt,
    super.uploaderName,
  });

  /// The upstream work id. Not globally unique on its own — combine with
  /// [pageIndex] via [id].
  final int illustId;

  /// Zero-based position of this page within its work.
  final int pageIndex;

  /// How many pages the parent work had in total.
  final int pageCount;

  final int userId;
  final String userName;
  final String userAccount;
  final PixivIllustType illustType;
  final int totalBookmarks;
  final int totalView;

  /// 0 = unspecified/not-AI, 1 = not AI-generated, 2 = AI-generated.
  final int aiType;

  final String? seriesTitle;

  /// True when [illustType] is [PixivIllustType.ugoira]. Playback of the full
  /// animation is out of scope — only the first frame renders.
  final bool isUgoira;

  /// True when the resolved image is one of Pixiv's placeholder images
  /// served for gated/restricted works, rather than the real artwork.
  final bool isRestricted;

  /// True when the parent work had more than one page.
  bool get hasMultiplePages => pageCount > 1;
}
