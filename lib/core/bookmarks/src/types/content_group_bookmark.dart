import 'package:equatable/equatable.dart';

import '../../../boorus/booru/types.dart';
import '../../../configs/config/src/types/profile_id.dart';
import '../../../content/types.dart';
import '../../../posts/related/related_posts_order_value.dart';
import 'bookmark.dart';
import 'stored_group_snapshot.dart';

class ContentGroupBookmark extends Equatable implements Bookmark {
  ContentGroupBookmark({
    required this.id,
    required this.snapshot,
    required DateTime createdAt,
    required DateTime observedAt,
    this.sourceProfileHint,
  }) : createdAt = createdAt.toUtc(),
       observedAt = observedAt.toUtc() {
    if (id < 0 ||
        id > maxBookmarkId ||
        (sourceProfileHint != null &&
            !isCanonicalProfileId(sourceProfileHint))) {
      throw const FormatException('Invalid saved Group');
    }
  }

  @override
  final int id;
  final StoredGroupSnapshot snapshot;
  final DateTime createdAt;
  final DateTime observedAt;
  final String? sourceProfileHint;
  ContentReference get reference => snapshot.summary.reference;
  ContentGroupSummary get summary => snapshot.summary;

  ContentGroupBookmark copyWith({
    int? id,
    StoredGroupSnapshot? snapshot,
    DateTime? createdAt,
    DateTime? observedAt,
    String? Function()? sourceProfileHint,
  }) => ContentGroupBookmark(
    id: id ?? this.id,
    snapshot: snapshot ?? this.snapshot,
    createdAt: createdAt ?? this.createdAt,
    observedAt: observedAt ?? this.observedAt,
    sourceProfileHint: sourceProfileHint == null
        ? this.sourceProfileHint
        : sourceProfileHint(),
  );

  @override
  List<Object?> get props => [
    id,
    snapshot,
    createdAt,
    observedAt,
    sourceProfileHint,
  ];
}

final class RelatedBookmark extends ContentGroupBookmark {
  RelatedBookmark({
    required super.id,
    required super.snapshot,
    required super.createdAt,
    required super.observedAt,
    super.sourceProfileHint,
    this.preferredOrder,
  }) {
    if (reference.engine != BooruType.danbooru ||
        !reference.sourceKey.startsWith('related:')) {
      throw const FormatException('Expected a Danbooru Related family');
    }
  }

  final RelatedPostsOrder? preferredOrder;

  @override
  RelatedBookmark copyWith({
    int? id,
    StoredGroupSnapshot? snapshot,
    DateTime? createdAt,
    DateTime? observedAt,
    String? Function()? sourceProfileHint,
    RelatedPostsOrder? Function()? preferredOrder,
  }) => RelatedBookmark(
    id: id ?? this.id,
    snapshot: snapshot ?? this.snapshot,
    createdAt: createdAt ?? this.createdAt,
    observedAt: observedAt ?? this.observedAt,
    sourceProfileHint: sourceProfileHint == null
        ? this.sourceProfileHint
        : sourceProfileHint(),
    preferredOrder: preferredOrder == null
        ? this.preferredOrder
        : preferredOrder(),
  );

  @override
  List<Object?> get props => [...super.props, preferredOrder];
}
