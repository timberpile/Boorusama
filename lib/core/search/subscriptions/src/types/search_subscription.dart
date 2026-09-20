// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'search_post_preview.dart';
import 'search_refresh.dart';

class SearchSubscription extends Equatable {
  SearchSubscription({
    required this.id,
    required this.profileId,
    required this.query,
    required this.position,
    required this.createdAt,
    required List<SearchPostPreview> previews,
    required List<RecentSearchPostIdentity> recentPostIdentities,
    required this.unreadCount,
    String? name,
    this.lastAttemptAt,
    this.lastSuccessfulCheckAt,
    this.lastErrorKind,
  }) : name = _normalizeSearchSubscriptionName(name),
       previews = List.unmodifiable(previews),
       recentPostIdentities = List.unmodifiable(recentPostIdentities);

  factory SearchSubscription.create({
    required String id,
    required int profileId,
    required String query,
    required String? name,
    required int position,
    required DateTime createdAt,
  }) {
    return SearchSubscription(
      id: id,
      profileId: profileId,
      query: query.trim(),
      position: position,
      createdAt: createdAt,
      previews: const [],
      recentPostIdentities: const [],
      unreadCount: 0,
      name: name,
    );
  }

  final String id;
  final int profileId;
  final String query;
  final String? name;
  final int position;
  final DateTime createdAt;
  final List<SearchPostPreview> previews;
  final List<RecentSearchPostIdentity> recentPostIdentities;
  final int unreadCount;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessfulCheckAt;
  final SearchRefreshErrorKind? lastErrorKind;

  String get displayName => name ?? query;
  bool get hasBaseline => lastSuccessfulCheckAt != null;

  @override
  List<Object?> get props => [
    id,
    profileId,
    query,
    name,
    position,
    createdAt,
    previews,
    recentPostIdentities,
    unreadCount,
    lastAttemptAt,
    lastSuccessfulCheckAt,
    lastErrorKind,
  ];
}

String normalizeSearchIdentity(String query) {
  return query.trim().split(RegExp(r'\s+')).join(' ');
}

String? _normalizeSearchSubscriptionName(String? name) {
  return switch (name?.trim()) {
    null || '' => null,
    final value => value,
  };
}
