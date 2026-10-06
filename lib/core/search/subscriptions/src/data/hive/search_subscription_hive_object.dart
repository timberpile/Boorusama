// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import 'recent_search_post_hive_object.dart';
import 'search_post_preview_hive_object.dart';

class SearchSubscriptionHiveObject extends HiveObject {
  SearchSubscriptionHiveObject({
    required this.id,
    required this.profileId,
    required this.query,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.lastAttemptAt,
    required this.lastSuccessfulCheckAt,
    this.highestSeenPostId,
    required this.unreadCount,
    required this.lastErrorKind,
    required this.previews,
    required this.recentPostIdentities,
    this.feedId,
    this.runtimeRevision = 0,
    this.queryStructure,
    this.adaptiveIntervalMilliseconds = 86400000,
    this.emptyAutomaticStreak = 0,
    this.lastMaterialEditAt,
  });

  int adaptiveIntervalMilliseconds;
  int emptyAutomaticStreak;
  DateTime? lastMaterialEditAt;
  String? feedId;
  int runtimeRevision;
  Object? queryStructure;
  String id;
  String profileId;
  String query;
  String? name;
  int position;
  DateTime createdAt;
  DateTime? lastAttemptAt;
  DateTime? lastSuccessfulCheckAt;
  int? highestSeenPostId;
  int unreadCount;
  String? lastErrorKind;
  List<SearchPostPreviewHiveObject> previews;
  List<RecentSearchPostHiveObject> recentPostIdentities;
}
