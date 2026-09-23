// Package imports:
import 'package:booru_clients/hydrus.dart';

// Project imports:
import '../../../core/boorus/booru/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import 'post_codec.dart';
import 'types.dart';

Post postDtoToPost(FileDto file, PostMetadata? metadata) {
  final record = HydrusPostRecord(
    id: file.fileId ?? 0,
    thumbnailImageUrl: file.thumbnailUrl,
    sampleImageUrl: file.imageUrl,
    originalImageUrl: file.imageUrl,
    tags: file.allTags,
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.from(file.firstSource),
    score: 0,
    duration: file.duration ?? 0,
    fileSize: file.size ?? 0,
    format: file.ext ?? '',
    hasSound: file.hasAudio,
    height: file.height?.toDouble() ?? 0,
    md5: file.hash ?? '',
    videoThumbnailUrl: file.thumbnailUrl,
    videoUrl: file.imageUrl,
    width: file.width?.toDouble() ?? 0,
    uploaderId: null,
    uploaderName: null,
    createdAt: null,
    metadata: metadata,
    ownFavorite: file.faved,
  );
  return hydrusPostFromRecord(
    record,
    PostOrigin.forBooruType(BooruType.hydrus),
  );
}
