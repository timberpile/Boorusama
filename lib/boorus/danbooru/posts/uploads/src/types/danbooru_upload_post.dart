// Project imports:
import '../../../../../../core/boorus/booru/types.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/posts/rating/types.dart';
import '../../../../../../core/posts/sources/types.dart';
import '../../../../users/user/types.dart';
import '../../../post/src/danbooru_post_codec.dart';
import '../../../post/types.dart';

class DanbooruUploadPost {
  factory DanbooruUploadPost({
    required int id,
    required String thumbnailImageUrl,
    required String sampleImageUrl,
    required String originalImageUrl,
    required Set<String> tags,
    required Set<String> copyrightTags,
    required Set<String> characterTags,
    required Set<String> artistTags,
    required Set<String> generalTags,
    required Set<String> metaTags,
    required double width,
    required double height,
    required String format,
    required String md5,
    required DateTime? lastCommentAt,
    required PostSource source,
    required DateTime? createdAt,
    required int score,
    required int upScore,
    required int downScore,
    required int favCount,
    required int uploaderId,
    required int? approverId,
    required Rating rating,
    required int fileSize,
    required bool hasChildren,
    required int? parentId,
    required bool hasLarge,
    required double duration,
    required PostVariants variants,
    required String pixelHash,
    required DanbooruUser? uploader,
    required int mediaAssetCount,
    required int postedCount,
    required int mediaAssetId,
    required int uploadId,
    required int uploadMediaAssetId,
    required String pageUrl,
    required String sourceRaw,
    required PostMetadata? metadata,
    required DanbooruPostStatus? status,
  }) {
    final post = danbooruPostFromRecord(
      DanbooruPostRecord(
        id: id,
        thumbnailImageUrl: thumbnailImageUrl,
        sampleImageUrl: sampleImageUrl,
        originalImageUrl: originalImageUrl,
        tags: tags,
        copyrightTags: copyrightTags,
        characterTags: characterTags,
        artistTags: artistTags,
        generalTags: generalTags,
        metaTags: metaTags,
        width: width,
        height: height,
        format: format,
        md5: md5,
        lastCommentAt: lastCommentAt,
        source: source,
        createdAt: createdAt,
        score: score,
        upScore: upScore,
        downScore: downScore,
        favCount: favCount,
        uploaderId: uploaderId,
        approverId: approverId,
        rating: rating,
        fileSize: fileSize,
        hasChildren: hasChildren,
        parentId: parentId,
        hasLarge: hasLarge,
        duration: duration,
        variants: variants,
        pixelHash: pixelHash,
        metadata: metadata,
        status: status,
      ),
      PostOrigin.forBooruType(BooruType.danbooru),
    );

    return DanbooruUploadPost._(
      post: post,
      uploader: uploader,
      mediaAssetCount: mediaAssetCount,
      postedCount: postedCount,
      mediaAssetId: mediaAssetId,
      uploadId: uploadId,
      uploadMediaAssetId: uploadMediaAssetId,
      pageUrl: pageUrl,
      sourceRaw: sourceRaw,
    );
  }

  DanbooruUploadPost._({
    required Post post,
    required this.uploader,
    required this.mediaAssetCount,
    required this.postedCount,
    required this.mediaAssetId,
    required this.uploadId,
    required this.uploadMediaAssetId,
    required this.pageUrl,
    required this.sourceRaw,
  }) : post = post;

  final Post post;
  final DanbooruUser? uploader;
  final int mediaAssetCount;
  final int postedCount;
  final int mediaAssetId;
  final int uploadId;
  final int uploadMediaAssetId;
  final String pageUrl;
  final String sourceRaw;

  int get id => post.id;
  int? get uploaderId => post.uploaderId;
  PostSource get source => post.source;
  int get fileSize => post.fileSize;
  double get width => post.width;
  double get height => post.height;
  double? get aspectRatio => post.aspectRatio;
  String get format => post.format;
  String get md5 => post.md5;
  String get pixelHash => post.pixelHash;
  String get url720x720 => post.url720x720;

  int get unPostedCount => mediaAssetCount - postedCount;
}
