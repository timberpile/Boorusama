// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../selected_tags/types.dart';
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
    required int unreadCount,
    String? name,
    SearchQueryStructure? queryStructure,
    this.lastAttemptAt,
    this.lastSuccessfulCheckAt,
    this.highestSeenPostId,
    this.lastErrorKind,
    this.runtimeRevision = 0,
  }) : queryStructure = switch (queryStructure) {
         final SearchQueryStructure structure
             when structure.matchesCanonicalQuery(query) =>
           structure,
         _ => null,
       },
       unreadCount = unreadCount > 0 ? 1 : 0,
       name = _normalizeSearchSubscriptionName(name),
       previews = List.unmodifiable(previews.take(4)),
       recentPostIdentities = List.unmodifiable(recentPostIdentities.take(50));

  factory SearchSubscription.create({
    required String id,
    required String profileId,
    required String query,
    required String? name,
    required int position,
    required DateTime createdAt,
    SearchQueryStructure? queryStructure,
  }) {
    return SearchSubscription(
      id: id,
      profileId: profileId,
      query: query.trim(),
      queryStructure: queryStructure,
      position: position,
      createdAt: createdAt,
      previews: const [],
      recentPostIdentities: const [],
      unreadCount: 0,
      name: name,
    );
  }

  final String id;
  final String profileId;
  final String query;
  final SearchQueryStructure? queryStructure;
  final String? name;
  final int position;
  final DateTime createdAt;
  final List<SearchPostPreview> previews;
  final List<RecentSearchPostIdentity> recentPostIdentities;
  final int unreadCount;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessfulCheckAt;
  final int? highestSeenPostId;
  final SearchRefreshErrorKind? lastErrorKind;
  final int runtimeRevision;

  String get displayName => name ?? query;
  bool get hasNewPosts => unreadCount > 0;
  bool get hasBaseline => lastSuccessfulCheckAt != null;

  @override
  List<Object?> get props => [
    id,
    profileId,
    query,
    queryStructure,
    name,
    position,
    createdAt,
    previews,
    recentPostIdentities,
    unreadCount,
    lastAttemptAt,
    lastSuccessfulCheckAt,
    highestSeenPostId,
    lastErrorKind,
    runtimeRevision,
  ];
}

final class SearchQueryStructure extends Equatable {
  const SearchQueryStructure._(this.typedTags);

  factory SearchQueryStructure.typedTags(Iterable<String> tags) {
    final values = tags.toList();
    if (values.isEmpty || values.any((tag) => tag.trim().isEmpty)) {
      throw ArgumentError.value(tags, 'tags', 'Tags must not be blank');
    }
    return SearchQueryStructure._(List.unmodifiable(values));
  }

  final List<String> typedTags;

  static SearchQueryStructure? tryParse(Object? value) => switch (value) {
    final Map json when json['kind'] == 'typed_tags' => switch (json['tags']) {
      final List tags
          when tags.isNotEmpty &&
              tags.every(
                (tag) => tag is String && tag.trim().isNotEmpty,
              ) =>
        SearchQueryStructure.typedTags(tags.cast<String>()),
      _ => null,
    },
    _ => null,
  };

  Map<String, Object> toJson() => {
    'kind': 'typed_tags',
    'tags': typedTags,
  };

  bool matchesCanonicalQuery(String query) =>
      typedTags.every(_preservesSingleQueryToken) &&
      normalizeSearchIdentity(
            SearchTagSet.fromList(typedTags).rawTagsString,
          ) ==
          normalizeSearchIdentity(query);

  @override
  List<Object?> get props => [typedTags];
}

bool _preservesSingleQueryToken(String tag) =>
    queryAsList('_${tag.replaceAll(' ', '_')}_').length == 1;

String normalizeSearchIdentity(String query) {
  return query.trim().split(RegExp(r'\s+')).join(' ');
}

String? _normalizeSearchSubscriptionName(String? name) {
  return switch (name?.trim()) {
    null || '' => null,
    final value => value,
  };
}
