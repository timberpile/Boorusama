// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../rating/types.dart';
import '../../../sources/types.dart';
import '../mixins/image_info_mixin.dart';
import '../mixins/media_info_mixin.dart';
import '../mixins/video_info_mixin.dart';
import 'booru_post_data.dart';
import 'post.dart';
import 'post_core_data.dart';
import 'post_media_aspect_ratios.dart';
import 'post_media_variants.dart';
import 'post_origin.dart';
import 'status.dart';

final class UnifiedPost extends Equatable
    with MediaInfoMixin, ImageInfoMixin, VideoInfoMixin
    implements Post, PostMediaVariants, PostMediaAspectRatios {
  const UnifiedPost({
    required this.origin,
    required this.core,
    required this.booruData,
  });

  final PostOrigin origin;
  final PostCoreData core;
  final BooruPostData booruData;

  @override
  int get id => core.id;
  @override
  DateTime? get createdAt => core.createdAt;
  @override
  String get thumbnailImageUrl => core.thumbnailImageUrl;
  @override
  String get sampleImageUrl => core.sampleImageUrl;
  @override
  String get originalImageUrl => core.originalImageUrl;
  @override
  String get videoUrl => core.videoUrl;
  @override
  String get videoThumbnailUrl => core.videoThumbnailUrl;
  @override
  Map<String, String> get mediaVariants => core.mediaVariants ?? const {};
  @override
  double? get thumbnailAspectRatio => core.thumbnailAspectRatio;
  @override
  double? get sampleAspectRatio => core.sampleAspectRatio;
  @override
  double? get originalAspectRatio => core.originalAspectRatio;
  @override
  double? get videoThumbnailAspectRatio => core.videoThumbnailAspectRatio;
  @override
  double? get videoAspectRatio => core.videoAspectRatio;
  @override
  double get width => core.width;
  @override
  double get height => core.height;
  @override
  String get format => core.format;
  @override
  String get md5 => core.md5;
  @override
  int get fileSize => core.fileSize;
  @override
  double get duration => core.duration;
  @override
  bool? get hasSound => core.hasSound;
  @override
  Set<String> get tags => core.tags;
  @override
  Set<String>? get artistTags => core.artistTags;
  @override
  Set<String>? get characterTags => core.characterTags;
  @override
  Set<String>? get copyrightTags => core.copyrightTags;
  @override
  Rating get rating => core.rating;
  @override
  bool get hasComment => core.hasComment;
  @override
  bool get isTranslated => core.isTranslated;
  @override
  bool get hasParentOrChildren => core.hasParentOrChildren;
  @override
  int? get parentId => core.parentId;
  @override
  PostSource get source => core.source;
  @override
  int get score => core.score;
  @override
  int? get downvotes => core.downvotes;
  @override
  int? get uploaderId => core.uploaderId;
  @override
  String? get uploaderName => core.uploaderName;
  @override
  PostStatus? get status => StringPostStatus.tryParse(core.status);
  @override
  PostMetadata? get metadata => core.metadata;

  @override
  List<Object?> get props => [origin, core, booruData];
}
