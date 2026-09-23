// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../../core/posts/post/types.dart';
import 'danbooru_post.dart';
import 'post_variant.dart';

final class DanbooruPostData extends Equatable implements BooruPostData {
  const DanbooruPostData({
    required this.lastCommentAt,
    required this.upScore,
    required this.downScore,
    required this.favCount,
    required this.approverId,
    required this.generalTags,
    required this.metaTags,
    required this.hasChildren,
    required this.hasLarge,
    required this.pixelHash,
  });

  factory DanbooruPostData.fromPost(DanbooruPostRecord post) =>
      DanbooruPostData(
        lastCommentAt: post.lastCommentAt,
        upScore: post.upScore,
        downScore: post.downScore,
        favCount: post.favCount,
        approverId: post.approverId,
        generalTags: post.generalTags,
        metaTags: post.metaTags,
        hasChildren: post.hasChildren,
        hasLarge: post.hasLarge,
        pixelHash: post.pixelHash,
      );

  final DateTime? lastCommentAt;
  final int upScore;
  final int downScore;
  final int favCount;
  final int? approverId;
  final Set<String> generalTags;
  final Set<String> metaTags;
  final bool hasChildren;
  final bool hasLarge;
  final String pixelHash;

  @override
  String get typeKey => 'danbooru';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    lastCommentAt,
    upScore,
    downScore,
    favCount,
    approverId,
    generalTags,
    metaTags,
    hasChildren,
    hasLarge,
    pixelHash,
  ];
}

extension DanbooruPostDataX on Post {
  DanbooruPostData? get danbooruData => switch (booruData) {
    final DanbooruPostData data => data,
    _ => null,
  };

  DateTime? get lastCommentAt => danbooruData?.lastCommentAt;
  int get upScore => danbooruData?.upScore ?? 0;
  int get downScore => danbooruData?.downScore ?? 0;
  int get favCount => danbooruData?.favCount ?? 0;
  int? get approverId => danbooruData?.approverId;
  Set<String> get generalTags => danbooruData?.generalTags ?? const {};
  Set<String> get metaTags => danbooruData?.metaTags ?? const {};
  bool get hasChildren => danbooruData?.hasChildren ?? false;
  bool get hasLarge => danbooruData?.hasLarge ?? false;
  String get pixelHash => danbooruData?.pixelHash ?? '';
  bool get isBanned => core.status == 'banned';
  bool get hasFavorite => favCount > 0;
  bool get hasVoter => upScore != 0 || downScore != 0;
  int get totalVote => upScore + -downScore;
  double get upvotePercent => totalVote > 0 ? upScore / totalVote : 1;
  Set<String> get allTags => {
    ...artistTags ?? const {},
    ...characterTags ?? const {},
    ...copyrightTags ?? const {},
    ...generalTags,
    ...metaTags,
  };

  PostVariants get variants => PostVariants.fromMap(mediaVariants);

  String get url180x180 => _variantOrFallback(
    PostQualityType.v180x180,
    thumbnailImageUrl,
  );

  String get url360x360 => _variantOrFallback(
    PostQualityType.v360x360,
    thumbnailImageUrl,
  );

  String get url720x720 => _variantOrFallback(
    PostQualityType.v720x720,
    thumbnailImageUrl,
  );

  String get urlSample => _variantOrFallback(
    PostQualityType.sample,
    sampleImageUrl,
  );

  String get urlOriginal => _variantOrFallback(
    PostQualityType.original,
    originalImageUrl,
  );

  String _variantOrFallback(PostQualityType type, String fallback) {
    final url = mediaVariants[type.value];
    return url == null || url.isEmpty ? fallback : url;
  }
}
