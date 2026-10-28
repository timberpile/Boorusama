import '../../sankaku/types/types.dart';
import 'post_dto.dart';

extension PostIdolDtoConverter on PostIdolDto {
  PostDto toSankakuPost() => PostDto(
    id: SankakuId.maybeFrom(id),
    createdAt: _sourceCreatedAt(createdAt),
    rating: rating,
    status: status,
    sampleUrl: sampleUrl,
    sampleWidth: sampleWidth,
    sampleHeight: sampleHeight,
    previewUrl: previewUrl,
    previewWidth: previewWidth,
    previewHeight: previewHeight,
    fileUrl: fileUrl,
    width: width,
    height: height,
    fileSize: fileSize,
    hasChildren: hasChildren,
    hasComments: hasComments,
    hasNotes: hasNotes,
    isFavorited: isFavorited,
    md5: md5,
    parentId: SankakuId.maybeFrom(parentId),
    change: change,
    favCount: favCount,
    recommendedPosts: recommendedPosts,
    voteCount: voteCount,
    totalScore: totalScore,
    commentCount: commentCount,
    inVisiblePool: inVisiblePool,
    isRatingLocked: isRatingLocked,
    isNoteLocked: isNoteLocked,
    isStatusLocked: isStatusLocked,
    tags: tags?.map((e) => e.toSankakuTag()).toList(),
    videoDuration: duration,
    author: AuthorDto(
      name: author,
    ),
  );
}

extension TagIdolDtoConverter on TagIdolDto {
  TagDto toSankakuTag() => TagDto(
    id: SankakuId.maybeFrom(id),
    name: nameEn,
    tagName: name,
    type: type,
    count: count,
    rating: rating,
  );
}

CreatedAtDto? _sourceCreatedAt(String? value) {
  final date = value == null ? null : DateTime.tryParse(value);
  if (date == null) return null;
  final micros = date.microsecondsSinceEpoch;
  final seconds = (micros / Duration.microsecondsPerSecond).floor();
  return CreatedAtDto(
    s: seconds,
    n: (micros - seconds * Duration.microsecondsPerSecond) * 1000,
  );
}
