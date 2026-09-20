// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'search_post_preview.dart';
import 'search_following_feed.dart';
import 'search_subscription.dart';

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
    required this.subscriptionId,
    required this.expectedCreatedAt,
    this.expectedRevision = 0,
    required this.expectedCheckpoint,
    required this.startedAt,
    required this.identityRetentionBoundary,
    required this.baseline,
    required List<SearchPostPreview> discoveredPosts,
    this.feedPosts = const [],
  }) : discoveredPosts = List.unmodifiable(discoveredPosts.take(50));

  final List<CachedFeedPost> feedPosts;
  final String subscriptionId;
  final DateTime expectedCreatedAt;
  final int expectedRevision;
  final DateTime? expectedCheckpoint;
  final DateTime startedAt;
  final DateTime identityRetentionBoundary;
  final bool baseline;
  final List<SearchPostPreview> discoveredPosts;

  @override
  List<Object?> get props => [
    subscriptionId,
    expectedCreatedAt,
    expectedRevision,
    expectedCheckpoint,
    startedAt,
    identityRetentionBoundary,
    baseline,
    discoveredPosts,
    feedPosts,
  ];
}

sealed class SearchRefreshOutcome extends Equatable {
  const SearchRefreshOutcome();
}

final class SearchRefreshSucceeded extends SearchRefreshOutcome {
  const SearchRefreshSucceeded({
    required this.subscription,
    required this.detectedNewPosts,
    required this.baseline,
  });

  final SearchSubscription subscription;
  final bool detectedNewPosts;
  final bool baseline;

  @override
  List<Object?> get props => [subscription, detectedNewPosts, baseline];
}

final class SearchRefreshFailed extends SearchRefreshOutcome {
  const SearchRefreshFailed(this.kind);

  final SearchRefreshErrorKind kind;

  @override
  List<Object?> get props => [kind];
}

final class SearchRefreshDiscarded extends SearchRefreshOutcome {
  const SearchRefreshDiscarded();

  @override
  List<Object?> get props => const [];
}

int compareSearchRefreshPriority(
  SearchSubscription left,
  SearchSubscription right,
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
