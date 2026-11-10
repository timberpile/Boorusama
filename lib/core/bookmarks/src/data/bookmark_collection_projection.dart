import '../../../content/types.dart';
import '../../../posts/post/types.dart';
import '../../../posts/related/related_family.dart';
import '../../../posts/related/related_posts_order_value.dart';
import '../types/bookmark.dart';
import '../types/content_group_bookmark.dart' as saved;
import '../types/legacy_group_bookmark.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_cover.dart';
import '../types/stored_group_snapshot.dart';

/// A compatibility view for existing Pool/Related screens. Neither the view's
/// membership fields nor its transient local-ID/locator inputs are persisted.
CollectionBookmark? bookmarkCollectionProjection(
  Bookmark record, {
  required Map<String, DateTime> memberships,
}) {
  if (record is LegacyGroupBookmark) {
    return record.metadata.copyWith(
      localId: '${record.id}',
      bookmarkId: () => record.id,
      sourceSite: () => null,
      groupIds: memberships.keys.toSet(),
      addedAt: memberships,
    );
  }
  if (record is! saved.ContentGroupBookmark) return null;
  final reference = record.reference;
  final related = record is saved.RelatedBookmark;
  final prefix = related ? 'related:' : 'pool:';
  if (!reference.sourceKey.startsWith(prefix)) return null;
  final upstreamId = int.tryParse(reference.sourceKey.substring(prefix.length));
  if (upstreamId == null || upstreamId <= 0) return null;
  final origin = PostOrigin.fromSource(
    booruType: reference.engine,
    booruId: reference.engine.id,
    source: reference.site.toString(),
    profileIdHint: record.sourceProfileHint,
  );
  final cover = record.summary.cover;
  final media = cover == null
      ? null
      : PoolBookmarkCover(
          thumbnail: cover.thumbnail.toString(),
          sample: (cover.sample ?? cover.thumbnail).toString(),
          original: (cover.original ?? cover.thumbnail).toString(),
          variants: cover.variants,
        );
  final index = record.snapshot.index;
  // Existing Pool filtering consumes a sampled member union. Native source
  // tags remain on Summary/Details rather than becoming a fabricated union.
  final memberIndex = index?.basis == GroupTagIndexBasis.memberUnion
      ? index
      : null;
  final tags = memberIndex?.tags ?? const <String>{};
  final coverage = PoolTagCoverage.values.byName(
    (memberIndex?.coverage ?? MetadataCoverage.unknown).name,
  );
  if (related) {
    return RelatedCollectionBookmark(
      localId: '${record.id}',
      bookmarkId: record.id,
      sourceSite: reference.site,
      loadedDetails: record.snapshot.details,
      family: RelatedFamilyReference(origin: origin, anchorId: upstreamId),
      createdAt: record.createdAt,
      observedAt: record.observedAt,
      groupIds: memberships.keys.toSet(),
      addedAt: memberships,
      tags: tags,
      coverage: coverage,
      total: record.summary.memberCount,
      cover: media,
      coverPolicy: index?.coverPolicy,
      newestUpload: index?.newestMemberUpload,
      oldestUpload: index?.oldestMemberUpload,
    );
  }
  return PoolBookmark(
    localId: '${record.id}',
    bookmarkId: record.id,
    sourceSite: reference.site,
    loadedDetails: record.snapshot.details,
    origin: origin,
    poolId: upstreamId,
    category: BookmarkedPoolCategory.values.firstWhere(
      (value) => value.name == record.summary.displayCategory,
      orElse: () => BookmarkedPoolCategory.unknown,
    ),
    title: record.summary.title ?? '',
    createdAt: record.createdAt,
    observedAt: record.observedAt,
    groupIds: memberships.keys.toSet(),
    addedAt: memberships,
    tags: tags,
    coverage: coverage,
    total: record.summary.memberCount,
    coverUrl: media?.thumbnail,
    cover: media,
    coverPolicy: index?.coverPolicy,
    newestUpload: index?.newestMemberUpload,
    oldestUpload: index?.oldestMemberUpload,
  );
}

/// Only a supplied proven locator or an existing validated reference can make
/// a native snapshot. Retained legacy facts never acquire a guessed scheme.
Bookmark collectionRecordForSave(
  CollectionBookmark metadata, {
  required int id,
  Bookmark? previous,
  RelatedPostsOrder? initialRelatedOrder,
}) {
  ContentReference? reference;
  if (metadata.sourceSite case final site?) {
    reference = const ContentReferenceCodec().parse(
      engine: metadata.origin.booruType,
      site: site,
      kind: ContentKind.group,
      sourceKey:
          '${metadata.isRelated ? 'related' : 'pool'}:${metadata.referenceId}',
    );
    if (reference.siteNamespace != metadata.origin.sourceHost ||
        metadata.sourceTypeId != reference.engine.id) {
      throw const FormatException(
        'Group draft locator disagrees with its source',
      );
    }
  } else if (metadata.loadedDetails case final details?) {
    reference = details.summary.reference;
  } else if (previous is saved.ContentGroupBookmark) {
    reference = previous.reference;
  }
  if (reference != null &&
      (reference.identity !=
              LegacyGroupBookmark.fromMetadata(
                id: 0,
                metadata: metadata,
              ).identity ||
          reference.engine != metadata.origin.booruType ||
          reference.engine.id != metadata.sourceTypeId)) {
    throw const FormatException('Incompatible Group metadata interpretation');
  }
  if (reference == null) {
    return LegacyGroupBookmark.fromMetadata(
      id: id,
      metadata: previous is LegacyGroupBookmark
          ? CollectionBookmark.fromJson({
              ...metadata.toJson(),
              'createdAt': previous.createdAt.toIso8601String(),
            })
          : metadata,
      preferredOrder: previous is LegacyRelatedGroupBookmark
          ? previous.preferredOrder
          : previous == null && metadata.isRelated
          ? initialRelatedOrder
          : null,
    );
  }
  final loaded = metadata.loadedDetails;
  if (loaded != null) {
    const ContentReferenceCodec().requireCompatible(
      reference,
      loaded.summary.reference,
    );
    if (reference.site != loaded.summary.reference.site) {
      throw const FormatException(
        'Loaded Group Details use a different locator',
      );
    }
  }
  final old = previous is saved.ContentGroupBookmark ? previous : null;
  final selectedCover = metadata.cover;
  final thumbnail = selectedCover?.thumbnail ?? metadata.coverUrl;
  final cover = thumbnail == null
      ? null
      : GroupCover(
          thumbnail: Uri.parse(thumbnail),
          sample: selectedCover == null
              ? null
              : Uri.parse(selectedCover.sample),
          original: selectedCover == null
              ? null
              : Uri.parse(selectedCover.original),
          variants: selectedCover?.variants ?? const {},
        );
  final summary = ContentGroupSummary(
    reference: reference,
    title: metadata.isRelated ? null : metadata.title,
    cover: cover,
    memberCount: metadata.total,
    displayCategory: metadata.category == BookmarkedPoolCategory.unknown
        ? null
        : metadata.category.name,
    previewTags: loaded?.summary.previewTags ?? old?.summary.previewTags,
    sourceData: loaded?.summary.sourceData ?? old?.summary.sourceData,
  );
  final snapshot = StoredGroupSnapshot(
    summary: summary,
    details:
        loaded?.withSummary(summary).mergeWithPrevious(old?.snapshot.details) ??
        old?.snapshot.details,
    index: GroupBookmarkIndex(
      tags: metadata.tags,
      basis: GroupTagIndexBasis.memberUnion,
      coverage: MetadataCoverage.values.byName(metadata.coverage.name),
      oldestMemberUpload: metadata.oldestUpload,
      newestMemberUpload: metadata.newestUpload,
      coverPolicy: metadata.coverPolicy,
    ),
  );
  final createdAt = switch (previous) {
    saved.ContentGroupBookmark() => previous.createdAt,
    LegacyGroupBookmark() => previous.createdAt,
    _ => metadata.createdAt,
  };
  return metadata.isRelated
      ? saved.RelatedBookmark(
          id: id,
          snapshot: snapshot,
          createdAt: createdAt,
          observedAt: metadata.observedAt,
          sourceProfileHint: metadata.origin.profileIdHint,
          preferredOrder: switch (previous) {
            saved.RelatedBookmark() => previous.preferredOrder,
            LegacyRelatedGroupBookmark() => previous.preferredOrder,
            _ => previous == null ? initialRelatedOrder : null,
          },
        )
      : saved.ContentGroupBookmark(
          id: id,
          snapshot: snapshot,
          createdAt: createdAt,
          observedAt: metadata.observedAt,
          sourceProfileHint: metadata.origin.profileIdHint,
        );
}
