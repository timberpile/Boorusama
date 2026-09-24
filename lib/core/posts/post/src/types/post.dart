// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../rating/types.dart';
import '../../../sources/types.dart';
import 'booru_post_data.dart';
import 'post_core_data.dart';
import 'post_media_aspect_ratios.dart';
import 'post_media_variants.dart';
import 'post_origin.dart';
import 'post_record.dart';
import '../mixins/image_info_mixin.dart';
import '../mixins/media_info_mixin.dart';
import '../mixins/video_info_mixin.dart';
import 'status.dart';

export 'post_id.dart';
export 'status.dart';

class PostMetadata extends Equatable {
  const PostMetadata({
    this.page,
    this.search,
    this.limit,
  });
  final int? page;
  final String? search;
  final int? limit;

  @override
  List<Object?> get props => [page, search, limit];
}

final class Post extends Equatable
    with MediaInfoMixin, ImageInfoMixin, VideoInfoMixin
    implements
        TagDetails,
        PostRecord,
        PostMediaVariants,
        PostMediaAspectRatios {
  const Post({
    required this.origin,
    required this.core,
    required this.booruData,
  });

  final PostOrigin origin;
  final PostCoreData core;
  final BooruPostData booruData;

  int get id => core.id;
  DateTime? get createdAt => core.createdAt;
  String get thumbnailImageUrl => core.thumbnailImageUrl;
  String get sampleImageUrl => core.sampleImageUrl;
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
  Set<String> get tags => core.tags;
  @override
  Set<String>? get artistTags => core.artistTags;
  @override
  Set<String>? get characterTags => core.characterTags;
  @override
  Set<String>? get copyrightTags => core.copyrightTags;
  Rating get rating => core.rating;
  bool get hasComment => core.hasComment;
  bool get isTranslated => core.isTranslated;
  bool get hasParentOrChildren => core.hasParentOrChildren;
  int? get parentId => core.parentId;
  PostSource get source => core.source;
  int get score => core.score;
  int? get downvotes => core.downvotes;
  int? get uploaderId => core.uploaderId;
  String? get uploaderName => core.uploaderName;
  PostStatus? get status => StringPostStatus.tryParse(core.status);
  PostMetadata? get metadata => core.metadata;

  Post copyWith({
    PostOrigin? origin,
    PostCoreData? core,
    BooruPostData? booruData,
  }) => Post(
    origin: origin ?? this.origin,
    core: core ?? this.core,
    booruData: booruData ?? this.booruData,
  );

  @override
  List<Object?> get props => [origin, core, booruData];
}

abstract interface class TagDetails {
  Set<String>? get artistTags;
  Set<String>? get characterTags;
  Set<String>? get copyrightTags;
}

extension PostImageX on Post {
  bool get hasFullView => originalImageUrl.isNotEmpty && !isVideo;

  bool get hasNoImage =>
      thumbnailImageUrl.isEmpty &&
      sampleImageUrl.isEmpty &&
      originalImageUrl.isEmpty;

  bool get hasParent => parentId != null && parentId! > 0;
}

extension PostX on Post {
  String get relationshipQuery => hasParent ? 'parent:$parentId' : 'parent:$id';
}
