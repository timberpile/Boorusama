import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../../bookmarks/src/types/pool_bookmark.dart';
import '../../../../bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../configs/config/types.dart';
import '../../../../posts/post/types.dart';

/// Cache identity includes the saved actor hint, unlike feed display deduplication.
String feedSeriesPostKey(PostOrigin origin, int postId) => jsonEncode([
  origin.booruType.id,
  origin.sourceHost,
  origin.profileIdHint,
  postId,
]);

bool feedSeriesMatchesConfig(PostOrigin origin, BooruConfig config) =>
    origin.booruType == config.auth.booruType &&
    origin.sourceHost == normalizePostSourceHost(config.url) &&
    (config.anonymousReadScope == null
        ? origin.profileIdHint == config.id
        : origin.profileIdHint == null && config.anonymousReadScope!.isCurrent);

class FeedSeriesSummary extends Equatable {
  const FeedSeriesSummary({required this.id, required this.title, this.total});

  factory FeedSeriesSummary.fromJson(Map value) {
    final id = value['id'];
    final title = value['title'];
    final total = value['total'];
    if (id is! int ||
        id <= 0 ||
        title is! String ||
        (total != null && (total is! int || total < 0))) {
      throw const FormatException('Invalid cached Series');
    }
    return FeedSeriesSummary(id: id, title: title, total: total as int?);
  }
  final int id;
  final String title;
  final int? total;

  RemoteBookmarkPool toPool() => RemoteBookmarkPool(
    id: id,
    title: title,
    total: total,
    category: BookmarkedPoolCategory.series,
  );

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'total': ?total};

  @override
  List<Object?> get props => [id, title, total];
}

/// Presence with an empty [series] list means a confirmed empty lookup. Absence
/// means unknown. A failed/partial response must not manufacture empty entries.
class FeedSeriesMembership extends Equatable {
  FeedSeriesMembership({
    required this.origin,
    required this.postId,
    required this.sourceId,
    required this.sourceRevision,
    required Iterable<FeedSeriesSummary> series,
  }) : series = List.unmodifiable(series);

  factory FeedSeriesMembership.fromJson(Map value) {
    final origin = value['origin'];
    final id = value['postId'];
    final sourceId = value['sourceId'];
    final revision = value['sourceRevision'];
    final series = value['series'];
    if (origin is! Map ||
        id is! int ||
        id <= 0 ||
        sourceId is! String ||
        sourceId.isEmpty ||
        revision is! int ||
        revision < 0 ||
        series is! List) {
      throw const FormatException('Invalid cached Series membership');
    }
    return FeedSeriesMembership(
      origin: PostOrigin.fromSnapshot(
        PostOriginSnapshot.fromJson(
          Map<String, dynamic>.from(origin),
        ),
      ),
      postId: id,
      sourceId: sourceId,
      sourceRevision: revision,
      series: [
        for (final item in series) FeedSeriesSummary.fromJson(item as Map),
      ],
    );
  }

  final PostOrigin origin;
  final int postId;
  final String sourceId;
  final int sourceRevision;
  final List<FeedSeriesSummary> series;
  String get key => feedSeriesPostKey(origin, postId);

  Map<String, Object?> toJson() => {
    'origin': origin.toSnapshot().toJson(),
    'postId': postId,
    'sourceId': sourceId,
    'sourceRevision': sourceRevision,
    'series': series.map((value) => value.toJson()).toList(),
  };

  static Map<String, FeedSeriesMembership> readCache(Object? raw) {
    final result = <String, FeedSeriesMembership>{};
    if (raw is! Map) return result;
    for (final value in raw.values) {
      try {
        final entry = FeedSeriesMembership.fromJson(value as Map);
        result[entry.key] = entry;
      } on Object {
        // Optional hints cannot invalidate otherwise usable cached Posts.
      }
    }
    return result;
  }

  @override
  List<Object?> get props => [origin, postId, sourceId, sourceRevision, series];
}

/// Equivalent URL spelling and display names do not change an actor binding.
bool feedSeriesSameActor(BooruConfig? a, BooruConfig? b) =>
    a != null &&
    b != null &&
    a.id == b.id &&
    a.auth.booruType == b.auth.booruType &&
    normalizePostSourceHost(a.url) == normalizePostSourceHost(b.url) &&
    a.auth.login == b.auth.login &&
    a.auth.apiKey == b.auth.apiKey &&
    a.auth.passHash == b.auth.passHash &&
    a.proxySettings == b.proxySettings &&
    a.networkSettings == b.networkSettings &&
    identical(a.anonymousReadScope, b.anonymousReadScope);
