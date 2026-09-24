// Package imports:
import 'package:booru_clients/danbooru.dart';

// Project imports:
import '../../../../../core/boorus/booru/types.dart';
import '../../../../../core/posts/post/tags.dart';
import '../../../../../core/posts/post/types.dart';
import '../../../../../core/posts/rating/types.dart';
import '../../../../../core/posts/sources/types.dart';
import 'danbooru_post.dart';
import 'danbooru_post_codec.dart';
import 'post_variant.dart';

Post postDtoToPostNoMetadata(PostDto dto) => postDtoToPost(dto, null);

Post emptyDanbooruPost() => danbooruPostFromRecord(
  DanbooruPostRecord.empty(),
  PostOrigin.forBooruType(BooruType.danbooru),
);

Post postDtoToPost(
  PostDto dto,
  PostMetadata? metadata,
) {
  try {
    final variants = PostVariants.fromMap(
      {
        for (final variant in dto.mediaAsset?.variants ?? <VariantDto>[])
          variant.type: variant.url,
      },
      fallback: () => _fallbackVariants(dto),
    );

    final record = DanbooruPostRecord(
      id: dto.id!,
      thumbnailImageUrl: dto.previewFileUrl ?? '',
      sampleImageUrl: dto.largeFileUrl ?? '',
      originalImageUrl: dto.fileUrl ?? '',
      tags: dto.tagString.splitTagString(),
      copyrightTags: dto.tagStringCopyright.splitTagString(),
      characterTags: dto.tagStringCharacter.splitTagString(),
      artistTags: dto.tagStringArtist.splitTagString(),
      generalTags: dto.tagStringGeneral.splitTagString(),
      metaTags: dto.tagStringMeta.splitTagString(),
      width: dto.imageWidth?.toDouble() ?? 0.0,
      height: dto.imageHeight?.toDouble() ?? 0.0,
      format: dto.fileExt ?? 'jpg',
      md5: dto.md5 ?? '',
      lastCommentAt: dto.lastCommentedAt != null
          ? DateTime.parse(dto.lastCommentedAt!)
          : null,
      source: PostSource.from(
        dto.source,
        pixivId: dto.pixivId,
      ),
      createdAt: DateTime.tryParse(dto.createdAt ?? ''),
      score: dto.score ?? 0,
      upScore: dto.upScore ?? 0,
      downScore: dto.downScore ?? 0,
      favCount: dto.favCount ?? 0,
      uploaderId: dto.uploaderId ?? 0,
      approverId: dto.approverId,
      rating: Rating.parse(dto.rating ?? 's'),
      fileSize: dto.fileSize ?? 0,
      hasChildren: dto.hasChildren ?? false,
      parentId: dto.parentId,
      hasLarge: dto.hasLarge ?? false,
      duration: dto.mediaAsset?.duration ?? 0,
      variants: variants,
      pixelHash: dto.mediaAsset?.pixelHash ?? '',
      metadata: metadata,
      status: DanbooruPostStatus.from(
        isBanned: dto.isBanned,
        isPending: dto.isPending,
        isFlagged: dto.isFlagged,
        isDeleted: dto.isDeleted,
      ),
    );
    return danbooruPostFromRecord(
      record,
      PostOrigin.forBooruType(BooruType.danbooru),
    );
  } catch (e) {
    return emptyDanbooruPost();
  }
}

List<PostVariant> _fallbackVariants(PostDto dto) {
  return [
    PostVariant.thumbnail(dto.previewFileUrl),
    PostVariant.sample(dto.largeFileUrl),
    PostVariant.original(dto.fileUrl),
  ];
}
