import 'package:equatable/equatable.dart';

import '../../../boorus/booru/types.dart';
import '../../../content/types.dart';
import '../../../posts/post/types.dart';
import '../../../posts/related/related_posts_order_value.dart';
import 'bookmark.dart';
import 'pool_bookmark.dart';
import 'stored_group_snapshot.dart';

/// Retains v9 source evidence when it cannot prove a complete installation URL.
/// It is a local Bookmark, not a fabricated ContentReference or new ContentKind.
/// Memberships always come from BookmarkGroup, including for these legacy rows.
sealed class LegacyGroupBookmark extends Equatable implements Bookmark {
  factory LegacyGroupBookmark.fromMetadata({
    required int id,
    required CollectionBookmark metadata,
    RelatedPostsOrder? preferredOrder,
  }) {
    if (id < 0 || (!metadata.isRelated && preferredOrder != null)) {
      throw const FormatException('Invalid retained legacy Group');
    }
    final detached = metadata.copyWith(
      localId: '$id',
      groupIds: const {},
      addedAt: const {},
    );
    return detached.isRelated
        ? LegacyRelatedGroupBookmark._(id, detached, preferredOrder)
        : _LegacyPoolGroupBookmark(id, detached);
  }

  const LegacyGroupBookmark._(this.id, this.metadata);

  @override
  final int id;
  final CollectionBookmark metadata;
  DateTime get createdAt => metadata.createdAt.toUtc();
  DateTime get observedAt => metadata.observedAt.toUtc();
  String? get sourceProfileHint => metadata.origin.profileIdHint;

  ContentIdentity? get identity {
    final engine = metadata.origin.booruType;
    if (engine == BooruType.unknown || metadata.sourceTypeId != engine.id) {
      return null;
    }
    try {
      final key = BooruContentKeyCodec(engine).canonicalize(
        ContentKind.group,
        '${metadata.isRelated ? 'related' : 'pool'}:${metadata.referenceId}',
      );
      return (
        siteNamespace: metadata.origin.sourceHost,
        kind: ContentKind.group,
        sourceKey: key,
      );
    } on FormatException {
      return null;
    }
  }

  /// The caller supplies an independently proven locator, such as the exact
  /// resolved current profile's URL. This conversion never authorizes requests
  /// or claims that the original legacy record retained its historical scheme.
  ContentReference? tryReferenceForProvenSite(Uri site) {
    final identity = this.identity;
    if (identity == null ||
        normalizePostSourceHost(site.toString()) != identity.siteNamespace) {
      return null;
    }
    try {
      return const ContentReferenceCodec().parse(
        engine: metadata.origin.booruType,
        site: site,
        kind: ContentKind.group,
        sourceKey: identity.sourceKey,
      );
    } on FormatException {
      return null;
    }
  }

  GroupBookmarkIndex get index => GroupBookmarkIndex(
    tags: metadata.tags,
    basis: GroupTagIndexBasis.memberUnion,
    coverage: MetadataCoverage.values.byName(metadata.coverage.name),
    oldestMemberUpload: metadata.oldestUpload,
    newestMemberUpload: metadata.newestUpload,
    coverPolicy: metadata.coverPolicy,
  );

  LegacyGroupBookmark copyWith({int? id, CollectionBookmark? metadata}) =>
      LegacyGroupBookmark.fromMetadata(
        id: id ?? this.id,
        metadata: metadata ?? this.metadata,
        preferredOrder: switch (this) {
          LegacyRelatedGroupBookmark(:final preferredOrder) => preferredOrder,
          _ => null,
        },
      );

  @override
  List<Object?> get props => [id, metadata];
}

final class _LegacyPoolGroupBookmark extends LegacyGroupBookmark {
  const _LegacyPoolGroupBookmark(super.id, super.metadata) : super._();
}

final class LegacyRelatedGroupBookmark extends LegacyGroupBookmark {
  const LegacyRelatedGroupBookmark._(
    super.id,
    super.metadata,
    this.preferredOrder,
  ) : super._();

  final RelatedPostsOrder? preferredOrder;

  @override
  LegacyGroupBookmark copyWith({
    int? id,
    CollectionBookmark? metadata,
    RelatedPostsOrder? Function()? preferredOrder,
  }) => LegacyGroupBookmark.fromMetadata(
    id: id ?? this.id,
    metadata: metadata ?? this.metadata,
    preferredOrder: preferredOrder == null
        ? this.preferredOrder
        : preferredOrder(),
  );

  @override
  List<Object?> get props => [...super.props, preferredOrder];
}
