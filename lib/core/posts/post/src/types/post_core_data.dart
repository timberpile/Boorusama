// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../rating/types.dart';
import '../../../sources/types.dart';
import 'post.dart';
import 'post_media_aspect_ratios.dart';
import 'post_media_variants.dart';
import 'status.dart';

final class PostCoreData extends Equatable {
  const PostCoreData({
    required this.id,
    required this.thumbnailImageUrl,
    required this.sampleImageUrl,
    required this.originalImageUrl,
    required this.videoUrl,
    required this.videoThumbnailUrl,
    required this.width,
    required this.height,
    required this.format,
    required this.md5,
    required this.fileSize,
    required this.duration,
    required this.tags,
    required this.rating,
    required this.hasComment,
    required this.isTranslated,
    required this.hasParentOrChildren,
    required this.source,
    required this.score,
    this.createdAt,
    this.mediaVariants,
    this.thumbnailAspectRatio,
    this.sampleAspectRatio,
    this.originalAspectRatio,
    this.videoThumbnailAspectRatio,
    this.videoAspectRatio,
    this.hasSound,
    this.artistTags,
    this.characterTags,
    this.copyrightTags,
    this.parentId,
    this.downvotes,
    this.uploaderId,
    this.uploaderName,
    this.status,
    this.metadata,
  });

  factory PostCoreData.fromPost(Post post, {String? status}) => PostCoreData(
    id: post.id,
    createdAt: post.createdAt,
    thumbnailImageUrl: post.thumbnailImageUrl,
    sampleImageUrl: post.sampleImageUrl,
    originalImageUrl: post.originalImageUrl,
    videoUrl: post.videoUrl,
    videoThumbnailUrl: post.videoThumbnailUrl,
    mediaVariants: switch (post) {
      PostMediaVariants(:final mediaVariants) => mediaVariants,
      _ => null,
    },
    thumbnailAspectRatio: switch (post) {
      PostMediaAspectRatios(:final thumbnailAspectRatio) =>
        thumbnailAspectRatio,
      _ => null,
    },
    sampleAspectRatio: switch (post) {
      PostMediaAspectRatios(:final sampleAspectRatio) => sampleAspectRatio,
      _ => null,
    },
    originalAspectRatio: switch (post) {
      PostMediaAspectRatios(:final originalAspectRatio) => originalAspectRatio,
      _ => null,
    },
    videoThumbnailAspectRatio: switch (post) {
      PostMediaAspectRatios(:final videoThumbnailAspectRatio) =>
        videoThumbnailAspectRatio,
      _ => null,
    },
    videoAspectRatio: switch (post) {
      PostMediaAspectRatios(:final videoAspectRatio) => videoAspectRatio,
      _ => null,
    },
    width: post.width,
    height: post.height,
    format: post.format,
    md5: post.md5,
    fileSize: post.fileSize,
    duration: post.duration,
    hasSound: post.hasSound,
    tags: post.tags,
    artistTags: post.artistTags,
    characterTags: post.characterTags,
    copyrightTags: post.copyrightTags,
    rating: post.rating,
    hasComment: post.hasComment,
    isTranslated: post.isTranslated,
    hasParentOrChildren: post.hasParentOrChildren,
    parentId: post.parentId,
    source: post.source,
    score: post.score,
    downvotes: post.downvotes,
    uploaderId: post.uploaderId,
    uploaderName: post.uploaderName,
    status:
        status ??
        switch (post.status) {
          StringPostStatus(:final value) => value,
          _ => null,
        },
    metadata: post.metadata,
  );

  final int id;
  final DateTime? createdAt;
  final String thumbnailImageUrl;
  final String sampleImageUrl;
  final String originalImageUrl;
  final String videoUrl;
  final String videoThumbnailUrl;
  final Map<String, String>? mediaVariants;
  final double? thumbnailAspectRatio;
  final double? sampleAspectRatio;
  final double? originalAspectRatio;
  final double? videoThumbnailAspectRatio;
  final double? videoAspectRatio;
  final double width;
  final double height;
  final String format;
  final String md5;
  final int fileSize;
  final double duration;
  final bool? hasSound;
  final Set<String> tags;
  final Set<String>? artistTags;
  final Set<String>? characterTags;
  final Set<String>? copyrightTags;
  final Rating rating;
  final bool hasComment;
  final bool isTranslated;
  final bool hasParentOrChildren;
  final int? parentId;
  final PostSource source;
  final int score;
  final int? downvotes;
  final int? uploaderId;
  final String? uploaderName;
  final String? status;
  final PostMetadata? metadata;

  @override
  List<Object?> get props => [
    id,
    createdAt,
    thumbnailImageUrl,
    sampleImageUrl,
    originalImageUrl,
    videoUrl,
    videoThumbnailUrl,
    mediaVariants,
    thumbnailAspectRatio,
    sampleAspectRatio,
    originalAspectRatio,
    videoThumbnailAspectRatio,
    videoAspectRatio,
    width,
    height,
    format,
    md5,
    fileSize,
    duration,
    hasSound,
    tags,
    artistTags,
    characterTags,
    copyrightTags,
    rating,
    hasComment,
    isTranslated,
    hasParentOrChildren,
    parentId,
    _sourceKey(source),
    score,
    downvotes,
    uploaderId,
    uploaderName,
    status,
    metadata,
  ];
}

Object _sourceKey(PostSource source) => switch (source) {
  NoSource() => const ['none'],
  NonWebSource(:final value) => ['nonWeb', value],
  PixivSource(:final url) => ['pixiv', url],
  RawWebSource(:final url) => ['web', url],
};
