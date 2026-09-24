// Package imports:
import 'package:booru_clients/gelbooru.dart';
import 'package:foundation/foundation.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../../core/boorus/booru/types.dart';
import '../../../core/posts/post/tags.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import 'post_codec.dart';
import 'types.dart';

Post gelbooruV2PostDtoToGelbooruPostNoMetadata(
  PostV2Dto dto,
  GelbooruV2ImageUrlResolver imageUrlResolver,
) => gelbooruV2PostDtoToGelbooruPost(dto, null, imageUrlResolver);

Post gelbooruV2PostDtoToGelbooruPost(
  PostV2Dto dto,
  PostMetadata? metadata,
  GelbooruV2ImageUrlResolver imageUrlResolver,
) {
  final previewUrl = imageUrlResolver.resolveThumbnailUrl(
    dto.previewUrl ?? '',
  );
  final sampleUrl = imageUrlResolver.resolvePreviewUrl(
    dto.sampleUrl ?? dto.fileUrl ?? '',
  );
  final fileUrl = imageUrlResolver.resolveImageUrl(
    dto.fileUrl ?? '',
  );

  final record = GelbooruV2PostRecord(
    id: dto.id!,
    thumbnailImageUrl: previewUrl,
    sampleImageUrl: sampleUrl,
    originalImageUrl: fileUrl,
    tags: dto.tags.splitTagString(),
    width: dto.width?.toDouble() ?? 0,
    height: dto.height?.toDouble() ?? 0,
    format: path.extension(dto.fileUrl ?? 'foo.png').substring(1),
    source: PostSource.from(dto.source),
    rating: Rating.parse(dto.rating ?? 'safe'),
    md5: dto.hash ?? '',
    hasComment: dto.commentCount != null && dto.commentCount! > 0,
    hasParentOrChildren: dto.parentId != null && dto.parentId != 0,
    fileSize: 0,
    score: dto.score ?? 0,
    createdAt: switch (dto.createdAt) {
      final String value => parseRFC822String(value),
      null => null,
    },
    parentId: dto.parentId != 0 ? dto.parentId : null,
    uploaderId: null,
    uploaderName: dto.owner,
    hasNotes: _checkIfHasNotes(dto),
    metadata: metadata,
    status: StringPostStatus.tryParse(dto.status),
    isVideoPreview: dto.isVideoPreview ?? false,
  );
  return gelbooruV2PostFromRecord(
    record,
    PostOrigin.forBooruType(BooruType.gelbooruV2),
  );
}

bool _checkIfHasNotes(PostV2Dto dto) {
  // if data contains hasNotes, return it
  if (dto.hasNotes != null) {
    return dto.hasNotes ?? false;
  }

  // check if tags contains 'translated' and not contains 'hard_translated'
  final tags = dto.tags.splitTagString();
  return tags.contains('translated') && !tags.contains('hard_translated');
}
