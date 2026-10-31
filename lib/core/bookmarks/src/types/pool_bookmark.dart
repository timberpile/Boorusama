import 'pool_bookmark_cover.dart';

import 'package:equatable/equatable.dart';

import '../../../posts/post/types.dart';

enum PoolTagCoverage { complete, partial, unknown }

enum BookmarkedPoolCategory { series, collection, unknown }

/// A remote collection reference. Member IDs and member snapshots are transient
/// indexing inputs and deliberately have no representation in this record.
final class PoolBookmark extends Equatable {
  PoolBookmark({
    required this.localId,
    required this.origin,
    required this.poolId,
    int? sourceTypeId,
    required this.category,
    required this.title,
    required this.createdAt,
    required this.observedAt,
    required Set<String> groupIds,
    required Set<String> tags,
    required this.coverage,
    this.total,
    this.coverUrl,
    this.cover,
    this.coverPolicy,
    this.newestUpload,
    this.oldestUpload,
  }) : sourceTypeId = sourceTypeId ?? origin.booruType.id,
       groupIds = Set.unmodifiable(groupIds),
       tags = Set.unmodifiable(tags) {
    if (localId.isEmpty ||
        poolId <= 0 ||
        origin.sourceHost.isEmpty ||
        (total != null && total! < 0) ||
        (oldestUpload != null &&
            newestUpload != null &&
            oldestUpload!.isAfter(newestUpload!))) {
      throw const FormatException('Invalid Pool bookmark');
    }
  }

  final String localId;
  final PostOrigin origin;
  final int poolId;
  final int sourceTypeId;
  final BookmarkedPoolCategory category;
  final String title;
  final DateTime createdAt;
  final DateTime observedAt;
  final Set<String> groupIds;
  final Set<String> tags;
  final PoolTagCoverage coverage;
  final int? total;
  final String? coverUrl;
  final PoolBookmarkCover? cover;

  /// Digest of non-secret visibility settings and effective blacklist.
  final String? coverPolicy;
  final DateTime? newestUpload;
  final DateTime? oldestUpload;

  (int, String, int) get identity => (sourceTypeId, origin.sourceHost, poolId);

  PoolBookmark withGroups(Set<String> groups) => copyWith(groupIds: groups);

  PoolBookmark copyWith({
    PostOrigin? origin,
    String? localId,
    Set<String>? groupIds,
    PoolBookmarkCover? cover,
  }) => PoolBookmark(
    localId: localId ?? this.localId,
    origin: origin ?? this.origin,
    poolId: poolId,
    sourceTypeId: sourceTypeId,
    category: category,
    title: title,
    createdAt: createdAt,
    observedAt: observedAt,
    groupIds: groupIds ?? this.groupIds,
    tags: tags,
    coverage: coverage,
    total: total,
    coverUrl: coverUrl,
    cover: cover ?? this.cover,
    coverPolicy: coverPolicy,
    newestUpload: newestUpload,
    oldestUpload: oldestUpload,
  );

  Map<String, Object?> toJson() => {
    'kind': 'pool',
    'localId': localId,
    'origin': origin.toSnapshot().toJson()..['booruTypeId'] = sourceTypeId,
    'poolId': poolId,
    'category': category.name,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'observedAt': observedAt.toIso8601String(),
    'groupIds': groupIds.toList()..sort(),
    'tags': tags.toList()..sort(),
    'coverage': coverage.name,
    'total': ?total,
    'coverUrl': ?coverUrl,
    'cover': ?cover?.toJson(),
    'coverPolicy': ?coverPolicy,
    'newestUpload': ?newestUpload?.toIso8601String(),
    'oldestUpload': ?oldestUpload?.toIso8601String(),
  };

  factory PoolBookmark.fromJson(Map<String, dynamic> json) {
    // Refuse unsupported entries rather than silently dropping them on a
    // subsequent write or export by an older application version.
    if (json['kind'] != 'pool') {
      throw const FormatException('Unsupported bookmark entry type');
    }
    final origin = PostOriginSnapshot.fromJson(
      Map<String, dynamic>.from(json['origin'] as Map),
    );
    return PoolBookmark(
      localId: json['localId'] as String,
      origin: PostOrigin.fromSnapshot(origin),
      sourceTypeId: origin.booruTypeId,
      poolId: json['poolId'] as int,
      category: BookmarkedPoolCategory.values.byName(
        json['category'] as String,
      ),
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      observedAt: DateTime.parse(json['observedAt'] as String),
      groupIds: (json['groupIds'] as List)
          .cast<String>()
          .map((id) => id.toLowerCase())
          .toSet(),
      tags: (json['tags'] as List).cast<String>().toSet(),
      coverage: PoolTagCoverage.values.byName(json['coverage'] as String),
      total: json['total'] as int?,
      coverUrl: json['coverUrl'] as String?,
      cover: switch (json['cover']) {
        final Map value => PoolBookmarkCover.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => null,
      },
      coverPolicy: json['coverPolicy'] as String?,
      newestUpload: switch (json['newestUpload']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      oldestUpload: switch (json['oldestUpload']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
    );
  }

  @override
  List<Object?> get props => [
    localId,
    origin,
    sourceTypeId,
    poolId,
    category,
    title,
    createdAt,
    observedAt,
    groupIds,
    tags,
    coverage,
    total,
    coverUrl,
    cover,
    coverPolicy,
    newestUpload,
    oldestUpload,
  ];
}
