import 'package:equatable/equatable.dart';

import '../../../rating/types.dart';
import '../../../sources/types.dart';
import '../mixins/image_info_mixin.dart';
import '../mixins/media_info_mixin.dart';
import '../mixins/post_mixin.dart';
import '../mixins/translatable_mixin.dart';
import '../mixins/video_info_mixin.dart';
import 'post.dart';

abstract interface class PostRecord {
  int get id;
  DateTime? get createdAt;
  String get thumbnailImageUrl;
  String get sampleImageUrl;
  String get originalImageUrl;
  String get videoUrl;
  String get videoThumbnailUrl;
  double get width;
  double get height;
  String get format;
  String get md5;
  int get fileSize;
  double get duration;
  bool? get hasSound;
  Set<String> get tags;
  Set<String>? get artistTags;
  Set<String>? get characterTags;
  Set<String>? get copyrightTags;
  Rating get rating;
  bool get hasComment;
  bool get isTranslated;
  bool get hasParentOrChildren;
  int? get parentId;
  PostSource get source;
  int get score;
  int? get downvotes;
  int? get uploaderId;
  String? get uploaderName;
  PostStatus? get status;
  PostMetadata? get metadata;
}

abstract class CommonPostRecord extends Equatable
    with
        MediaInfoMixin,
        TranslatedMixin,
        ImageInfoMixin,
        VideoInfoMixin,
        NoTagDetailsRecordMixin,
        TagListCheckMixin
    implements PostRecord {
  CommonPostRecord({
    required this.id,
    required this.thumbnailImageUrl,
    required this.sampleImageUrl,
    required this.originalImageUrl,
    required this.tags,
    required this.rating,
    required this.hasComment,
    required this.isTranslated,
    required this.hasParentOrChildren,
    required this.source,
    required this.score,
    required this.duration,
    required this.fileSize,
    required this.format,
    required this.hasSound,
    required this.height,
    required this.md5,
    required this.videoThumbnailUrl,
    required this.videoUrl,
    required this.width,
    required this.uploaderId,
    required this.metadata,
    this.createdAt,
    this.parentId,
    this.downvotes,
    this.uploaderName,
    this.status,
  });

  @override
  final int id;
  @override
  final DateTime? createdAt;
  @override
  final String thumbnailImageUrl;
  @override
  final String sampleImageUrl;
  @override
  final String originalImageUrl;
  @override
  final Set<String> tags;
  @override
  final Rating rating;
  @override
  final bool hasComment;
  @override
  final bool isTranslated;
  @override
  final bool hasParentOrChildren;
  @override
  final int? parentId;
  @override
  final PostSource source;
  @override
  final int score;
  @override
  final int? downvotes;
  @override
  final double duration;
  @override
  final int fileSize;
  @override
  final String format;
  @override
  final bool? hasSound;
  @override
  final double height;
  @override
  final String md5;
  @override
  final String videoThumbnailUrl;
  @override
  final String videoUrl;
  @override
  final double width;
  @override
  final int? uploaderId;
  @override
  final String? uploaderName;
  @override
  final PostMetadata? metadata;
  @override
  final PostStatus? status;

  @override
  List<Object?> get props => [id];
}

mixin NoTagDetailsRecordMixin implements PostRecord {
  @override
  Set<String>? get artistTags => null;
  @override
  Set<String>? get characterTags => null;
  @override
  Set<String>? get copyrightTags => null;
}
