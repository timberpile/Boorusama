// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:equatable/equatable.dart';

/// What the Explore page's grid is currently showing: a feed is "what to
/// call, with which params".
///
/// A sealed hierarchy rather than an enum-plus-parallel-state so each feed
/// owns exactly the params it needs — adding a fourth feed later means
/// adding one more subclass and one more switch arm, never touching the
/// existing ones.
sealed class PixivExploreFeed extends Equatable {
  const PixivExploreFeed();
}

/// The pixiv Ranking feed: a [PixivRankingMode] snapshot for one JST day.
class PixivRankingFeed extends PixivExploreFeed {
  const PixivRankingFeed({
    required this.mode,
    required this.date,
  });

  final PixivRankingMode mode;
  final DateTime date;

  PixivRankingFeed copyWith({
    PixivRankingMode? mode,
    DateTime? date,
  }) => PixivRankingFeed(
    mode: mode ?? this.mode,
    date: date ?? this.date,
  );

  @override
  List<Object?> get props => [mode, date];
}

/// Illusts from artists the account follows.
class PixivFollowingFeed extends PixivExploreFeed {
  const PixivFollowingFeed({
    this.restrict = PixivFollowRestrict.all,
  });

  final PixivFollowRestrict restrict;

  PixivFollowingFeed copyWith({
    PixivFollowRestrict? restrict,
  }) => PixivFollowingFeed(restrict: restrict ?? this.restrict);

  @override
  List<Object?> get props => [restrict];
}

/// The personalized recommended feed. Carries no params.
class PixivRecommendedFeed extends PixivExploreFeed {
  const PixivRecommendedFeed();

  @override
  List<Object?> get props => [];
}

/// The kinds of feed the Explore page's top selector switches between. A
/// thin UI-facing label for a [PixivExploreFeed]'s variant — the actual
/// request params live on the feed itself, not here.
enum PixivExploreFeedKind {
  ranking,
  following,
  recommended,
}

PixivExploreFeedKind pixivExploreFeedKindOf(PixivExploreFeed feed) =>
    switch (feed) {
      PixivRankingFeed() => PixivExploreFeedKind.ranking,
      PixivFollowingFeed() => PixivExploreFeedKind.following,
      PixivRecommendedFeed() => PixivExploreFeedKind.recommended,
    };

/// The feed a switch to [kind] should start on.
///
/// Ranking and Following remember their previously chosen mode/date/restrict
/// when [current] is already that kind, so hopping to another feed and back
/// doesn't lose the selection; otherwise a fresh default is used. The mode
/// selector and date stepper are meaningless outside Ranking, and the
/// restrict toggle outside Following — this is exactly why: switching away
/// from Ranking can never leave a stray mode/date on a Following or
/// Recommended feed, because those types simply have no such fields to
/// carry one on.
PixivExploreFeed pixivDefaultFeedFor(
  PixivExploreFeedKind kind, {
  required PixivExploreFeed current,
  required DateTime newestRankingDate,
}) => switch (kind) {
  PixivExploreFeedKind.ranking =>
    current is PixivRankingFeed
        ? current
        : PixivRankingFeed(mode: PixivRankingMode.day, date: newestRankingDate),
  PixivExploreFeedKind.following =>
    current is PixivFollowingFeed ? current : const PixivFollowingFeed(),
  PixivExploreFeedKind.recommended => const PixivRecommendedFeed(),
};
