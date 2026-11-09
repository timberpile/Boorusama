import 'package:booru_clients/pixiv.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/post/src/data/origin_aware_post_repository.dart';
import '../posts/parser.dart';
import '../posts/types.dart';

GroupCoverVisibility pixivWorkVisibility(PixivIllustDto dto) =>
    GroupCoverVisibility(
      tags: dto.tags.map((tag) => tag.name).nonNulls,
      tagCoverage: switch (dto.tagCoverage) {
        PixivTagCoverage.complete => MetadataCoverage.complete,
        PixivTagCoverage.partial => MetadataCoverage.partial,
        _ => MetadataCoverage.unknown,
      },
      rating: switch (dto.xRestrict) {
        0 => 'general',
        1 || 2 => 'explicit',
        _ => 'unknown',
      },
      deleted: false,
      banned: false,
    );

ContentReference pixivWorkReference(
  ContentAccessContext access,
  int illustId,
) => _reference(access, ContentKind.group, 'work:$illustId');

ContentReference pixivPageReference(
  ContentAccessContext access,
  int illustId,
  int pageIndex,
) => _reference(access, ContentKind.post, 'work-page:$illustId:$pageIndex');

ContentReference _reference(
  ContentAccessContext access,
  ContentKind kind,
  String sourceKey,
) {
  if (access.key.engine != BooruType.pixiv || access.key.profileId == null) {
    throw const FormatException('Pixiv Works require their captured account');
  }
  return const ContentReferenceCodec().parse(
    engine: BooruType.pixiv,
    site: Uri.parse(access.config!.url),
    kind: kind,
    sourceKey: sourceKey,
  );
}

/// Maps only the source's existing list envelope; no detail/media reads occur.
/// Ugoira remains a real animation Post rather than a Group of frame images.
List<ContentEntry> pixivWorkListingEntries(
  PixivIllustListResult result, {
  required ContentAccessContext access,
  PostMetadata? metadata,
}) => [
  for (final dto in result.illusts)
    if (pixivWorkIsVisible(dto))
      if (PixivIllustType.parse(dto.type) == PixivIllustType.ugoira)
        for (final post in pixivWorkPagePosts(
          dto,
          access,
          metadata: metadata,
        ).take(1))
          PostContentEntry(
            reference: pixivPageReference(
              access,
              post.illustId,
              post.pageIndex,
            ),
            post: post,
          )
      else
        GroupContentEntry(summary: pixivWorkSummary(dto, access)),
];

bool pixivWorkIsVisible(PixivIllustDto dto) =>
    (dto.id ?? 0) > 0 &&
    (dto.user?.id ?? 0) > 0 &&
    (dto.visible ?? true) &&
    !(dto.isMuted ?? false);

ContentGroupSummary pixivWorkSummary(
  PixivIllustDto dto,
  ContentAccessContext access,
) {
  if (!pixivWorkIsVisible(dto) ||
      PixivIllustType.parse(dto.type) == PixivIllustType.ugoira) {
    throw const FormatException('Unavailable Pixiv Work');
  }
  final thumbnail = _safeUri(dto.imageUrls?.squareMedium);
  return ContentGroupSummary(
    reference: pixivWorkReference(access, dto.id!),
    title: dto.title,
    memberCount: switch (dto.pageCount) {
      final count? when count > 0 => count,
      _ => null,
    },
    displayCategory: dto.type,
    // A list preview is not evidence of an available page or original URL.
    cover: thumbnail == null
        ? null
        : GroupCover(
            thumbnail: thumbnail,
            visibility: pixivWorkVisibility(dto),
          ),
    previewTags: pixivWorkTags(dto),
  );
}

ContentGroupDetails pixivWorkDetails(
  PixivIllustDto dto,
  ContentAccessContext access,
) => ContentGroupDetails(
  summary: pixivWorkSummary(dto, access),
  description: dto.caption == null
      ? null
      : GroupDescription(text: dto.caption!, format: GroupTextFormat.html),
  creators: switch (dto.user) {
    final user? when user.name?.trim().isNotEmpty ?? false => [
      CreatorRef(
        displayName: user.name!,
        sourceKey: user.id == null ? null : 'user:${user.id}',
        account: user.account,
        avatar: _safeUri(user.profileImageUrls?.medium),
        sourceUrl: user.id == null
            ? null
            : Uri.https('www.pixiv.net', '/users/${user.id}'),
      ),
    ],
    _ => null,
  },
  tags: pixivWorkTags(dto),
  sourceDates: dto.createDate == null
      ? null
      : GroupSourceDates(createdAt: DateTime.tryParse(dto.createDate!)),
);

/// Existing parser and codec own the deployed Page IDs and media variants.
/// Work captions remain on Details; they are not page-specific evidence.
List<Post> pixivWorkPagePosts(
  PixivIllustDto dto,
  ContentAccessContext access, {
  PostMetadata? metadata,
}) {
  _reference(access, ContentKind.group, 'work:${dto.id}');
  final config = access.config;
  if (config == null) throw const FormatException('Unavailable Pixiv account');
  return [
    for (final post in illustDtoToPosts(dto, metadata: metadata))
      post
          .copyWith(origin: postOriginFromConfig(config))
          .withDetailFacts(
            PostDetailFacts.fromJson({
              ...post.detailFacts.toJson()..remove('description'),
            }),
          ),
  ];
}

GroupTags? pixivWorkTags(PixivIllustDto dto) {
  if (dto.tagCoverage == PixivTagCoverage.unknown) {
    return null;
  }
  return GroupTags(
    coverage: dto.tagCoverage == PixivTagCoverage.complete
        ? MetadataCoverage.complete
        : MetadataCoverage.partial,
    values: [
      for (final tag in dto.tags)
        if (tag.name case final name? when name.isNotEmpty)
          GroupTag(name: name, displayName: tag.translatedName),
    ],
  );
}

Uri? _safeUri(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  try {
    validateGroupMetadataUri(uri);
    return uri;
  } on FormatException {
    return null;
  }
}
