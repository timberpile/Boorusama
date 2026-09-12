// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/errors/types.dart';
import '../../../core/posts/explores/types.dart';
import '../../../core/posts/post/types.dart';
import '../client_provider.dart';
import '../posts/parser.dart';
import '../posts/types.dart';
import 'feed.dart';

/// Pixiv's ranking is offset-paged at 30 items/page (see `PixivClient`,
/// which computes the offset itself from the `page` it is given). Kept
/// here, alongside a test, purely so a future change to either side's
/// formula surfaces as a broken assertion rather than a silent mismatch.
int pixivRankingOffsetFor(int page) => (page - 1) * 30;

/// Maps the shared [TimeScale] control onto pixiv's ranking modes.
///
/// This only covers the day/week/month scale toggle offered within the
/// Ranking feed. The other ranking modes (male/female/rookie/ai/manga/R-18
/// variants) are reached through the mode selector instead, which carries a
/// [PixivRankingMode] directly rather than going through [TimeScale].
PixivRankingMode pixivRankingModeFrom(TimeScale scale) => switch (scale) {
  TimeScale.day => PixivRankingMode.day,
  TimeScale.week => PixivRankingMode.week,
  TimeScale.month => PixivRankingMode.month,
};

/// The date part of `now`, expressed in JST (UTC+9, pixiv observes no DST),
/// as a UTC-flagged date-only [DateTime] so it compares cleanly against
/// other date-only values.
DateTime pixivJstToday({DateTime? now}) {
  final jst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return DateTime.utc(jst.year, jst.month, jst.day);
}

/// The newest ranking snapshot pixiv can have published.
///
/// Pixiv's ranking is an immutable per-JST-day snapshot: today's has not
/// been tallied yet, and requesting it 404s ("ranking tally out of
/// range"), so the newest available one is always JST yesterday.
DateTime pixivRankingNewestDate({DateTime? now}) =>
    pixivJstToday(now: now).subtract(const Duration(days: 1));

/// Clamps [date] into pixiv's valid ranking window
/// (`[2007-09-13, JST yesterday]`), comparing by calendar date only.
///
/// `DateTimeSelector` is a shared core widget whose date picker allows
/// picking outside this window (its `firstDate`/`lastDate` predate pixiv
/// entirely and postdate the newest snapshot), and its step arrows have no
/// way to be disabled at either boundary. Every value it produces is
/// clamped here before use, rather than firing a request that is
/// guaranteed to 404.
DateTime clampPixivRankingDate(DateTime date, {DateTime? now}) {
  final dateOnly = DateTime.utc(date.year, date.month, date.day);
  final newest = pixivRankingNewestDate(now: now);

  if (dateOnly.isBefore(kPixivRankingEarliestDate)) {
    return kPixivRankingEarliestDate;
  }
  if (dateOnly.isAfter(newest)) {
    return newest;
  }

  return dateOnly;
}

/// Whether [date] is the newest snapshot available.
///
/// When true, the `date` query parameter should be omitted entirely so the
/// API returns whatever it considers its newest published ranking, rather
/// than the date we predicted — avoiding an off-by-one 404 if pixiv
/// publishes on a slightly different schedule than assumed.
bool isPixivRankingNewestDate(DateTime date, {DateTime? now}) {
  final dateOnly = DateTime.utc(date.year, date.month, date.day);

  return !dateOnly.isBefore(pixivRankingNewestDate(now: now));
}

/// The `date` value to pass to `PixivClient.getRanking` for a selected
/// [date]: `null` when [date] is the newest available snapshot (so the API
/// picks its own newest), the clamped date otherwise.
DateTime? pixivRankingRequestDateFor(DateTime date, {DateTime? now}) =>
    isPixivRankingNewestDate(date, now: now)
    ? null
    : clampPixivRankingDate(date, now: now);

/// Whether to show the "R-18 hidden" warning for [feed] given the account's
/// stored `x_restrict` level.
///
/// Deliberately different from pxview, which silently omits modes the
/// account cannot currently see: a wrong reading of the flag must not lock
/// anyone out of content they are entitled to, so this warns rather than
/// gates — the request is still made either way. A `null` account level
/// (never captured, or a malformed `passHash`) never warns: there is no
/// evidence the account can't see the mode, only an absence of evidence.
bool pixivShouldWarnXRestrict(PixivExploreFeed feed, int? accountXRestrict) {
  if (accountXRestrict == null) return false;

  return switch (feed) {
    PixivRankingFeed(:final mode) => mode.minimumXRestrict > accountXRestrict,
    PixivFollowingFeed() || PixivRecommendedFeed() => false,
  };
}

final pixivExploreRepoProvider =
    Provider.family<PixivExploreRepository, BooruConfigAuth>((ref, config) {
      final client = ref.watch(pixivClientProvider(config));

      return PixivExploreRepository(client: client);
    });

class PixivExploreRepository {
  PixivExploreRepository({required this.client});

  final PixivClient client;

  /// The page beyond which a given feed is known to have run out, per the
  /// API's own `next_url` signal (see `PixivIllustListResult.hasMore`) —
  /// set once a page's response omits it, so later pages short-circuit
  /// instead of firing a request past the end of the feed. Keyed per feed
  /// (see [_cacheKeyFor]) so switching feeds — or the ranking mode/date
  /// within one — doesn't inherit another feed's exhaustion point.
  final Map<String, int> _exhaustedAfterPage = {};

  PostsOrError<PixivPost> getPosts({
    required PixivExploreFeed feed,
    required int page,
    DateTime? now,
  }) {
    final key = _cacheKeyFor(feed);
    final exhaustedAfter = _exhaustedAfterPage[key];
    if (exhaustedAfter != null && page > exhaustedAfter) {
      return TaskEither.of(const <PixivPost>[].toResult());
    }

    return TaskEither.tryCatch(
      () async {
        final result = await switch (feed) {
          PixivRankingFeed(:final mode, :final date) => client.getRanking(
            mode: mode,
            date: pixivRankingRequestDateFor(date, now: now),
            page: page,
          ),
          PixivFollowingFeed(:final restrict) => client.getFollowedIllusts(
            restrict: restrict,
            page: page,
          ),
          PixivRecommendedFeed() => client.getRecommendedIllusts(page: page),
        };

        // GOTCHA: pixiv returns stub illusts for some flagged works
        // (`visible: false`) even to R-18-enabled accounts, and the parser
        // drops them — so a 30-item API page routinely yields fewer than 30
        // posts. `hasMore` must come from `next_url` only (which
        // `PixivIllustListResult` already does), never from a short page.
        if (!result.hasMore) {
          _exhaustedAfterPage[key] = page;
        }

        return illustDtosToPosts(result.illusts).toResult();
      },
      _mapError,
    );
  }

  static String _cacheKeyFor(PixivExploreFeed feed) => switch (feed) {
    PixivRankingFeed(:final mode, :final date) =>
      'ranking:${mode.value}:${date.toIso8601String()}',
    PixivFollowingFeed(:final restrict) => 'following:${restrict.value}',
    PixivRecommendedFeed() => 'recommended',
  };

  /// Mirrors `tryFetchRemoteData`'s (core/http/client) `DioException`
  /// mapping, with one addition at the top: the shared rate limiter (see
  /// `client_provider.dart`'s `PixivRateLimitSuppressionInterceptor`)
  /// rejects requests during its 300s back-off window with a cancel-type
  /// `DioException` instead of letting one through to fail normally. That
  /// is surfaced as a rate-limit `ServerError` — reusing the app's
  /// existing "You're being rate limited" copy — rather than as an empty
  /// page, so rapid arrow-tapping during suppression reads as "wait a
  /// bit", not as "no posts for this date".
  ///
  /// `tryFetchRemoteData` itself is not reused here because its own
  /// certificate/handshake detection is private to that file; an
  /// unrecognized `DioException` still falls back to the same
  /// `cannotReachServer` classification it would use.
  static BooruError _mapError(Object error, StackTrace stackTrace) =>
      switch (error) {
        DioException(type: DioExceptionType.cancel) => ServerError(
          httpStatusCode: 429,
          message: 'Pixiv rate limit active; suppressing requests.',
        ),
        DioException(:final response?) => ServerError(
          httpStatusCode: response.statusCode,
          message: switch (response.data) {
            final String s => s,
            {'message': final String s} => s,
            final other => '$other',
          },
        ),
        DioException() => AppError(
          type: AppErrorType.cannotReachServer,
          message: error.toString(),
        ),
        _ => AppError(
          type: AppErrorType.loadDataFromServerFailed,
          message: error.toString(),
        ),
      };
}
