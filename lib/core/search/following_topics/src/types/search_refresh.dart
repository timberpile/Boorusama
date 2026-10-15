// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../posts/post/types.dart';
import 'search_post_preview.dart';
import 'following_topic.dart';

enum SearchRefreshErrorKind {
  network,
  authentication,
  query,
  pagination,
  parsing,
  unsupported,
  other,
  tagLimit,
  rateLimited,
}

class SearchRefreshCommit extends Equatable {
  SearchRefreshCommit({
    required this.topicId,
    required this.expectedCreatedAt,
    this.expectedRevision = 0,
    required this.expectedCheckpoint,
    required this.startedAt,
    required this.identityRetentionBoundary,
    required this.baseline,
    required List<SearchPostPreview> discoveredPosts,
    this.feedPosts = const [],
    this.delta = false,
    this.truncated = false,
    this.canCommit,
    bool automatic = false,
    this.automaticResolver,
  }) : _automatic = automatic,
       discoveredPosts = List.unmodifiable(discoveredPosts);

  /// Checked after acquiring the serialized write boundary, before mutation.
  final bool Function()? canCommit;
  final List<StoredPostSnapshot> feedPosts;
  final bool delta;
  final bool truncated;
  final String topicId;
  final DateTime expectedCreatedAt;
  final int expectedRevision;
  final DateTime? expectedCheckpoint;
  final DateTime startedAt;
  final DateTime identityRetentionBoundary;
  final bool baseline;
  final bool _automatic;
  final bool Function()? automaticResolver;
  bool get automatic => automaticResolver?.call() ?? _automatic;
  final List<SearchPostPreview> discoveredPosts;

  @override
  List<Object?> get props => [
    topicId,
    expectedCreatedAt,
    expectedRevision,
    expectedCheckpoint,
    startedAt,
    identityRetentionBoundary,
    baseline,
    discoveredPosts,
    feedPosts,
    delta,
    truncated,
    canCommit,
    automatic,
  ];
}

sealed class SearchRefreshOutcome extends Equatable {
  const SearchRefreshOutcome();
}

final class SearchRefreshSucceeded extends SearchRefreshOutcome {
  const SearchRefreshSucceeded({
    required this.topic,
    required this.detectedNewPosts,
    required this.baseline,
  });

  final FollowingTopic topic;
  final bool detectedNewPosts;
  final bool baseline;

  @override
  List<Object?> get props => [topic, detectedNewPosts, baseline];
}

final class SearchRefreshFailed extends SearchRefreshOutcome {
  const SearchRefreshFailed(this.kind);

  final SearchRefreshErrorKind kind;

  @override
  List<Object?> get props => [kind];
}

final class SearchRefreshDeferred extends SearchRefreshOutcome {
  const SearchRefreshDeferred(this.retryAt);
  final DateTime retryAt;
  @override
  List<Object?> get props => [retryAt];
}

final class SearchRefreshDiscarded extends SearchRefreshOutcome {
  const SearchRefreshDiscarded();

  @override
  List<Object?> get props => const [];
}

int compareSearchRefreshPriority(
  FollowingTopic left,
  FollowingTopic right,
) {
  return switch ((left.lastSuccessfulCheckAt, right.lastSuccessfulCheckAt)) {
    (null, null) => left.id.compareTo(right.id),
    (null, _) => -1,
    (_, null) => 1,
    (final leftChecked?, final rightChecked?) => switch (leftChecked.compareTo(
      rightChecked,
    )) {
      0 => left.id.compareTo(right.id),
      final result => result,
    },
  };
}
