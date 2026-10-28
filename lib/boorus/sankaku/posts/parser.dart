// Package imports:
import 'package:booru_clients/sankaku.dart';
import 'package:coreutils/coreutils.dart';

// Project imports:
import '../../../core/boorus/booru/types.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import '../../../core/tags/tag/types.dart';
import '../../../core/tags/categories/types.dart';
import '../tags/categories.dart';
import 'post_codec.dart';
import 'types.dart';

Post postDtoToPost(
  PostDto e,
  PostIdGenerator idGenerator,
  PostMetadata? metadata,
) {
  final hasParent = e.parentId != null;
  final hasChilren = e.hasChildren ?? false;
  final hasParentOrChildren = hasParent || hasChilren;
  final detailedTags = sankakuTagDtosToTags(e.tags);
  final artistTags = detailedTags
      .where(
        (tag) =>
            tag.category == TagCategory.artist() ||
            tag.category == kSankakuStudioTagCategory,
      )
      .toList();
  final characterTags = detailedTags
      .where((tag) => tag.category == TagCategory.character())
      .toList();
  final copyrightTags = detailedTags
      .where((tag) => tag.category == TagCategory.copyright())
      .toList();
  final generalTags = detailedTags
      .where((tag) => tag.category == TagCategory.general())
      .toList();
  final metaTags = detailedTags
      .where(
        (tag) =>
            !artistTags.contains(tag) &&
            !characterTags.contains(tag) &&
            !copyrightTags.contains(tag) &&
            !generalTags.contains(tag),
      )
      .toList();

  final timestamp = e.createdAt?.s;
  final nanos = e.createdAt?.n;
  final subsecondMicros = nanos != null && nanos >= 0 && nanos < 1000000000
      ? nanos ~/ 1000
      : 0;

  final (id, sankakuId) = switch (e.id) {
    // No id, so we generate a pseudo id for shared post plumbing.
    null => (idGenerator.generateId(), null),
    // Int id, which means they reverted back to int id
    IntId i => (i.value, i),
    // String id, which means they are using string id
    StringId s => (idGenerator.generateId(), s),
  };

  final record = SankakuPostRecord(
    id: id,
    sankakuId: sankakuId,
    isFavorited: e.isFavorited ?? false,
    favoriteCount: e.favCount ?? 0,
    thumbnailImageUrl: e.previewUrl ?? '',
    sampleImageUrl: e.sampleUrl ?? '',
    originalImageUrl: e.fileUrl ?? '',
    tags: e.tags?.map((e) => e.tagName).nonNulls.toSet() ?? {},
    rating: Rating.parseLegacy(e.rating),
    hasComment: e.hasComments ?? false,
    isTranslated: false,
    hasParentOrChildren: hasParentOrChildren,
    source: PostSource.from(e.source),
    score: e.totalScore ?? 0,
    duration: e.videoDuration ?? 0,
    fileSize: e.fileSize ?? 0,
    format:
        extractFileExtension(
          e.fileType,
          fileUrl: e.fileUrl,
        ) ??
        '',
    hasSound: null,
    height: e.height?.toDouble() ?? 0,
    md5: e.md5 ?? '',
    videoThumbnailUrl: e.previewUrl ?? '',
    videoUrl: e.fileUrl ?? '',
    width: e.width?.toDouble() ?? 0,
    artistDetailsTags: artistTags,
    characterDetailsTags: characterTags,
    copyrightDetailsTags: copyrightTags,
    generalDetailsTags: generalTags,
    metaDetailsTags: metaTags,
    createdAt: timestamp != null
        ? DateTime.fromMicrosecondsSinceEpoch(
            timestamp * Duration.microsecondsPerSecond + subsecondMicros,
          )
        : null,
    uploaderId: null, // Source account IDs may be strings.
    uploaderName: e.author?.name,
    metadata: metadata,
    status: StringPostStatus.tryParse(e.status),
  );
  return sankakuPostFromRecord(
    record,
    PostOrigin.forBooruType(BooruType.sankaku),
  ).withDetailFacts(
    PostDetailFacts(
      originalByteSize: e.fileSize,
      originalWidth: e.width?.toDouble(),
      originalHeight: e.height?.toDouble(),
      originalFormat: extractFileExtension(e.fileType, fileUrl: e.fileUrl),
      score: e.totalScore,
      favoriteCount: e.favCount,
      commentCount: e.commentCount,
    ),
  );
}

List<Tag> sankakuTagDtosToTags(List<TagDto>? tags) {
  if (tags == null) return const [];

  final parsed = <Object, Tag>{};
  for (final dto in tags) {
    final name = dto.tagName;
    if (name == null || name.isEmpty) continue;

    final key = switch (dto.id) {
      final id? => (id: id),
      null => (name: name, type: dto.type),
    };
    final tag = Tag(
      name: name,
      category: sankakuTagCategoryFromApiId(dto.type),
      postCount: dto.postCount ?? dto.count ?? 0,
    );
    final existing = parsed[key];
    if (existing == null || tag.postCount > existing.postCount) {
      parsed[key] = tag;
    }
  }

  return parsed.values.toList(growable: false);
}

String? extractFileExtension(
  String? mimeType, {
  String? fileUrl,
}) {
  if (mimeType == null) {
    if (fileUrl == null) return null;

    final ext = urlExtension(fileUrl);

    return ext;
  }

  final parts = mimeType.split('/');
  return parts.length >= 2 ? '.${parts[1]}' : null;
}
