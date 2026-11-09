import 'package:booru_clients/nhentai.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/post/src/data/origin_aware_post_repository.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import '../posts/data.dart';

ContentReference nhentaiGalleryReference(ContentAccessContext access, int id) =>
    _reference(access, ContentKind.group, 'gallery:$id');

ContentReference nhentaiPageReference(
  ContentAccessContext access,
  int galleryId,
  int pageNumber,
) =>
    _reference(access, ContentKind.post, 'gallery-page:$galleryId:$pageNumber');

ContentReference _reference(
  ContentAccessContext access,
  ContentKind kind,
  String key,
) {
  if (access.key.engine != BooruType.nhentai ||
      access.key.siteNamespace != 'nhentai.net') {
    throw const FormatException('Foreign nhentai source');
  }
  return const ContentReferenceCodec().parse(
    engine: BooruType.nhentai,
    site: Uri.parse('https://nhentai.net'),
    kind: kind,
    sourceKey: key,
  );
}

ContentGroupSummary nhentaiGallerySummary(
  NhentaiGallerySummary dto,
  ContentAccessContext access,
  NhentaiMediaPolicy policy, {
  Map<int, NhentaiTag> resolvedTags = const {},
}) => ContentGroupSummary(
  reference: nhentaiGalleryReference(access, dto.id),
  title: dto.englishTitle ?? dto.japaneseTitle,
  memberCount: dto.pageCount,
  cover: _cover(
    policy,
    dto.mediaId,
    dto.thumbnailPath,
    dto.thumbnailWidth,
    dto.thumbnailHeight,
    visibility:
        dto.tagIdCoverage == NhentaiTagCoverage.complete &&
            dto.tagIds.every(resolvedTags.containsKey)
        ? _visibility(dto.tagIds.map((id) => resolvedTags[id]!))
        : null,
  ),
  previewTags: dto.tagIdCoverage == NhentaiTagCoverage.unknown
      ? null
      : GroupTags(
          values: [
            for (final id in dto.tagIds)
              GroupTag(
                sourceId: '$id',
                name: resolvedTags[id]?.name,
                category: resolvedTags[id]?.type,
              ),
          ],
          coverage:
              dto.tagIdCoverage == NhentaiTagCoverage.complete &&
                  dto.tagIds.every(resolvedTags.containsKey)
              ? MetadataCoverage.complete
              : MetadataCoverage.partial,
        ),
);

ContentGroupDetails nhentaiGalleryDetails(
  NhentaiGalleryDetails dto,
  ContentAccessContext access,
  NhentaiMediaPolicy policy,
) {
  final tags = nhentaiGroupTags(dto);
  return ContentGroupDetails(
    summary: ContentGroupSummary(
      reference: nhentaiGalleryReference(access, dto.id),
      title: dto.englishTitle ?? dto.japaneseTitle,
      memberCount: dto.pageCount,
      cover: _cover(
        policy,
        dto.mediaId,
        dto.thumbnail?.path,
        dto.thumbnail?.width,
        dto.thumbnail?.height,
        visibility: dto.tagCoverage == NhentaiTagCoverage.complete
            ? _visibility(dto.tags)
            : null,
      ),
      previewTags: tags,
    ),
    tags: tags,
    sourceDates: dto.uploadedAt == null
        ? null
        : GroupSourceDates(publishedAt: dto.uploadedAt),
    creators: dto.tagCoverage != NhentaiTagCoverage.complete
        ? null
        : [
            for (final tag in dto.tags)
              if (tag.type == 'artist')
                CreatorRef(
                  displayName: tag.name,
                  sourceKey: 'artist:${tag.id}',
                ),
          ],
  );
}

GroupTags? nhentaiGroupTags(NhentaiGalleryDetails dto) =>
    dto.tagCoverage == NhentaiTagCoverage.unknown
    ? null
    : GroupTags(
        values: [
          for (final tag in dto.tags)
            GroupTag(sourceId: '${tag.id}', name: tag.name, category: tag.type),
        ],
        coverage: dto.tagCoverage == NhentaiTagCoverage.complete
            ? MetadataCoverage.complete
            : MetadataCoverage.partial,
      );

GroupCover? _cover(
  NhentaiMediaPolicy policy,
  String? mediaId,
  String? path,
  int? width,
  int? height, {
  GroupCoverVisibility? visibility,
}) {
  final uri = nhentaiMediaUri(policy, mediaId, path, thumbnail: true);
  return uri == null
      ? null
      : GroupCover(
          thumbnail: uri,
          width: width != null && width > 0 ? width : null,
          height: height != null && height > 0 ? height : null,
          visibility: visibility,
        );
}

GroupCoverVisibility _visibility(
  Iterable<NhentaiTag> tags,
) => GroupCoverVisibility(
  tags: {
    for (final tag in tags) ...[
      tag.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      '${tag.type}:${tag.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
    ],
  },
  rating: 'unknown',
  deleted: false,
  banned: false,
);

/// Invalid or absent source media remains unavailable; no URL is synthesized.
Uri? nhentaiMediaUri(
  NhentaiMediaPolicy policy,
  String? mediaId,
  String? path, {
  bool thumbnail = false,
}) {
  if (mediaId == null || path == null || path.isEmpty) return null;
  try {
    return policy.resolve(mediaId: mediaId, path: path, thumbnail: thumbnail);
  } on FormatException {
    return null;
  }
}

List<Post> nhentaiGalleryPosts(
  NhentaiGalleryDetails dto,
  ContentAccessContext access,
  NhentaiMediaPolicy policy,
) => [
  for (final page in dto.pages ?? const <NhentaiPage>[])
    if (nhentaiMediaUri(policy, dto.mediaId, page.path) case final original?)
      Post(
        origin: postOriginFromConfig(access.config!),
        booruData: NhentaiPostData(galleryId: dto.id, pageNumber: page.number),
        core: PostCoreData(
          id: NhentaiPageIdentity(
            galleryId: dto.id,
            pageNumber: page.number,
          ).numericPostId,
          thumbnailImageUrl:
              nhentaiMediaUri(
                policy,
                dto.mediaId,
                page.thumbnailPath,
                thumbnail: true,
              )?.toString() ??
              '',
          sampleImageUrl: original.toString(),
          originalImageUrl: original.toString(),
          videoUrl: '',
          videoThumbnailUrl: '',
          width: page.width?.toDouble() ?? 0,
          height: page.height?.toDouble() ?? 0,
          format: original.path.split('.').last,
          md5: '',
          fileSize: 0,
          duration: 0,
          tags: const {},
          rating: Rating.unknown,
          hasComment: false,
          isTranslated: false,
          hasParentOrChildren: false,
          source: PostSource.from(
            'https://nhentai.net/g/${dto.id}/${page.number}/',
          ),
          score: 0,
          detailFacts: PostDetailFacts(
            originalWidth: page.width?.toDouble(),
            originalHeight: page.height?.toDouble(),
            originalFormat: original.path.split('.').last,
          ),
        ),
      ),
];
