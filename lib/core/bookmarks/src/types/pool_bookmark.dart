import 'pool_bookmark_cover.dart';
import '../../../posts/related/related_family.dart';
import '../../../content/types.dart';

import 'package:equatable/equatable.dart';

import '../../../posts/post/types.dart';

enum PoolTagCoverage { complete, partial, unknown }

enum BookmarkedPoolCategory { series, collection, unknown }

/// A remote collection reference. Member IDs and member snapshots are transient
/// indexing inputs and deliberately have no representation in this record.
class CollectionBookmark extends Equatable {
  CollectionBookmark._({
    required this.localId,
    required this.origin,
    this.bookmarkId,
    this.sourceSite,
    this.loadedDetails,
    required this.referenceId,
    this.family,
    int? sourceTypeId,
    required this.category,
    required this.title,
    required this.createdAt,
    required this.observedAt,
    required Set<String> groupIds,
    Map<String, DateTime> addedAt = const {},
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
       addedAt = Map.unmodifiable({
         for (final id in groupIds) id: (addedAt[id] ?? createdAt).toUtc(),
       }),
       tags = Set.unmodifiable(tags) {
    if ((bookmarkId != null && bookmarkId! < 0) ||
        localId.isEmpty ||
        referenceId <= 0 ||
        origin.sourceHost.isEmpty ||
        (total != null && total! < 0) ||
        (oldestUpload != null &&
            newestUpload != null &&
            oldestUpload!.isAfter(newestUpload!))) {
      throw const FormatException('Invalid collection bookmark');
    }
  }

  final String localId;
  // Transient presentation inputs, never serialized into legacy metadata.
  // Local record identity and a proven locator come from the owning repository
  // or an explicit current-source draft, never from imported numeric IDs.
  final int? bookmarkId;
  final Uri? sourceSite;
  final ContentGroupDetails? loadedDetails;
  final PostOrigin origin;
  final int referenceId;
  final RelatedFamilyReference? family;
  bool get isRelated => family != null;
  final int sourceTypeId;
  final BookmarkedPoolCategory category;
  final String title;
  final DateTime createdAt;
  final DateTime observedAt;
  final Set<String> groupIds;
  final Map<String, DateTime> addedAt;
  final Set<String> tags;
  final PoolTagCoverage coverage;
  final int? total;
  final String? coverUrl;
  final PoolBookmarkCover? cover;

  /// Digest of non-secret visibility settings and effective blacklist.
  final String? coverPolicy;
  final DateTime? newestUpload;
  final DateTime? oldestUpload;

  Object get identity =>
      family?.identity ?? (sourceTypeId, origin.sourceHost, referenceId);

  CollectionBookmark withGroups(
    Set<String> groups, {
    Map<String, DateTime>? addedAt,
    DateTime? now,
  }) => copyWith(
    groupIds: groups,
    addedAt:
        addedAt ??
        {
          ...this.addedAt,
          for (final id in groups.difference(groupIds))
            id: now ?? DateTime.now(),
        },
  );

  CollectionBookmark copyWith({
    PostOrigin? origin,
    String? localId,
    int? Function()? bookmarkId,
    Uri? Function()? sourceSite,
    ContentGroupDetails? Function()? loadedDetails,
    Set<String>? groupIds,
    Map<String, DateTime>? addedAt,
    PoolBookmarkCover? cover,
  }) => CollectionBookmark._(
    localId: localId ?? this.localId,
    bookmarkId: bookmarkId == null ? this.bookmarkId : bookmarkId(),
    sourceSite: sourceSite == null ? this.sourceSite : sourceSite(),
    loadedDetails: loadedDetails == null ? this.loadedDetails : loadedDetails(),
    origin: origin ?? this.origin,
    referenceId: referenceId,
    family: family == null
        ? null
        : RelatedFamilyReference(
            origin: origin ?? this.origin,
            anchorId: family!.anchorId,
          ),
    sourceTypeId: sourceTypeId,
    category: category,
    title: title,
    createdAt: createdAt,
    observedAt: observedAt,
    groupIds: groupIds ?? this.groupIds,
    addedAt: addedAt ?? this.addedAt,
    tags: tags,
    coverage: coverage,
    total: total,
    coverUrl: coverUrl,
    cover: cover ?? this.cover,
    coverPolicy: coverPolicy,
    newestUpload: newestUpload,
    oldestUpload: oldestUpload,
  )._typed();

  Map<String, Object?> toJson() => {
    'kind': isRelated ? 'related' : 'pool',
    'localId': localId,
    'origin': origin.toSnapshot().toJson()..['booruTypeId'] = sourceTypeId,
    if (isRelated) 'anchorId': family!.anchorId else 'poolId': referenceId,
    'category': category.name,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'observedAt': observedAt.toIso8601String(),
    'groupIds': groupIds.toList()..sort(),
    'addedAt': addedAt.map(
      (id, date) => MapEntry(id, date.toUtc().toIso8601String()),
    ),
    'tags': tags.toList()..sort(),
    'coverage': coverage.name,
    'total': ?total,
    'coverUrl': ?coverUrl,
    'cover': ?cover?.toJson(),
    'coverPolicy': ?coverPolicy,
    'newestUpload': ?newestUpload?.toIso8601String(),
    'oldestUpload': ?oldestUpload?.toIso8601String(),
  };

  factory CollectionBookmark.fromJson(Map<String, dynamic> json) {
    final memberIds = (json['groupIds'] as List)
        .cast<String>()
        .map((id) => id.toLowerCase())
        .toSet();
    final dates = _parseMembershipDates(json['addedAt']);
    if (!memberIds.containsAll(dates.keys)) {
      throw const FormatException('Membership date references an absent group');
    }
    // Refuse unsupported entries rather than silently dropping them on a
    // subsequent write or export by an older application version.
    if (json['kind'] != 'pool' && json['kind'] != 'related') {
      throw const FormatException('Unsupported bookmark entry type');
    }
    if ((json['kind'] == 'related' && json.containsKey('poolId')) ||
        (json['kind'] == 'pool' && json.containsKey('anchorId'))) {
      throw const FormatException('Conflicting bookmark reference IDs');
    }
    if (json['kind'] == 'related' &&
        (json['category'] != BookmarkedPoolCategory.unknown.name ||
            json['title'] != '')) {
      throw const FormatException('Invalid Related metadata');
    }
    final origin = PostOriginSnapshot.fromJson(
      Map<String, dynamic>.from(json['origin'] as Map),
    );
    return CollectionBookmark._(
      localId: json['localId'] as String,
      origin: PostOrigin.fromSnapshot(origin),
      sourceTypeId: origin.booruTypeId,
      referenceId:
          (json['kind'] == 'related' ? json['anchorId'] : json['poolId'])
              as int,
      family: json['kind'] == 'related'
          ? RelatedFamilyReference(
              origin: PostOrigin.fromSnapshot(origin),
              anchorId: json['anchorId'] as int,
            )
          : null,
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
      addedAt: dates,
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
    )._typed();
  }

  CollectionBookmark _typed() => family == null
      ? PoolBookmark(
          poolId: referenceId,
          localId: localId,
          bookmarkId: bookmarkId,
          sourceSite: sourceSite,
          loadedDetails: loadedDetails,
          origin: origin,
          sourceTypeId: sourceTypeId,
          category: category,
          title: title,
          createdAt: createdAt,
          observedAt: observedAt,
          groupIds: groupIds,
          addedAt: addedAt,
          tags: tags,
          coverage: coverage,
          total: total,
          coverUrl: coverUrl,
          cover: cover,
          coverPolicy: coverPolicy,
          newestUpload: newestUpload,
          oldestUpload: oldestUpload,
        )
      : RelatedCollectionBookmark(
          family: family!,
          localId: localId,
          bookmarkId: bookmarkId,
          sourceSite: sourceSite,
          loadedDetails: loadedDetails,
          createdAt: createdAt,
          observedAt: observedAt,
          groupIds: groupIds,
          addedAt: addedAt,
          tags: tags,
          coverage: coverage,
          total: total,
          cover: cover,
          coverPolicy: coverPolicy,
          newestUpload: newestUpload,
          oldestUpload: oldestUpload,
        );

  @override
  List<Object?> get props => [
    localId,
    bookmarkId,
    sourceSite,
    loadedDetails,
    origin,
    sourceTypeId,
    referenceId,
    family,
    category,
    title,
    createdAt,
    observedAt,
    groupIds,
    addedAt,
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

final class PoolBookmark extends CollectionBookmark {
  PoolBookmark({
    required int poolId,
    required super.localId,
    required super.origin,
    super.bookmarkId,
    super.sourceSite,
    super.loadedDetails,
    int? sourceTypeId,
    required super.category,
    required super.title,
    required super.createdAt,
    required super.observedAt,
    required super.groupIds,
    super.addedAt,
    required super.tags,
    required super.coverage,
    super.total,
    super.coverUrl,
    super.cover,
    super.coverPolicy,
    super.newestUpload,
    super.oldestUpload,
  }) : super._(referenceId: poolId, sourceTypeId: sourceTypeId);
  int get poolId => referenceId;
  @override
  (int, String, int) get identity => (sourceTypeId, origin.sourceHost, poolId);
  factory PoolBookmark.fromJson(Map<String, dynamic> json) {
    if (json['kind'] != 'pool')
      throw const FormatException('Expected Pool bookmark');
    return CollectionBookmark.fromJson(json) as PoolBookmark;
  }
}

final class RelatedCollectionBookmark extends CollectionBookmark {
  RelatedCollectionBookmark({
    required RelatedFamilyReference family,
    required String localId,
    int? bookmarkId,
    Uri? sourceSite,
    ContentGroupDetails? loadedDetails,
    required DateTime createdAt,
    required DateTime observedAt,
    required Set<String> groupIds,
    Map<String, DateTime> addedAt = const {},
    Set<String> tags = const {},
    PoolTagCoverage coverage = PoolTagCoverage.unknown,
    int? total,
    PoolBookmarkCover? cover,
    String? coverPolicy,
    DateTime? newestUpload,
    DateTime? oldestUpload,
  }) : super._(
         localId: localId,
         bookmarkId: bookmarkId,
         sourceSite: sourceSite,
         loadedDetails: loadedDetails,
         origin: family.origin,
         referenceId: family.anchorId,
         family: family,
         category: BookmarkedPoolCategory.unknown,
         title: '',
         createdAt: createdAt,
         observedAt: observedAt,
         groupIds: groupIds,
         addedAt: addedAt,
         tags: tags,
         coverage: coverage,
         total: total,
         coverUrl: cover?.thumbnail,
         cover: cover,
         coverPolicy: coverPolicy,
         newestUpload: newestUpload,
         oldestUpload: oldestUpload,
       );
}

Map<String, DateTime> _parseMembershipDates(Object? raw) {
  if (raw == null) return const {};
  if (raw is! Map) throw const FormatException('Invalid membership dates');
  final dates = <String, DateTime>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (entry.key is! String || value is! String) {
      throw const FormatException('Invalid membership date');
    }
    final date = DateTime.tryParse(value);
    if (date == null) throw const FormatException('Invalid membership date');
    dates[(entry.key as String).toLowerCase()] = date;
  }
  return dates;
}
