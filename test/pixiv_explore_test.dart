// Dart imports:
import 'dart:convert';
import 'dart:typed_data';

// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Project imports:
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/boorus/pixiv/explore/feed.dart';
import 'package:boorusama/boorus/pixiv/explore/providers.dart';
import 'package:boorusama/core/posts/explores/types.dart';
import 'package:boorusama/core/posts/explores/widgets.dart';

void main() {
  group('JST-yesterday computation', () {
    final cases = [
      (
        description: 'a UTC instant that is still the previous JST day',
        // 2024-03-10 12:00 UTC -> 2024-03-10 21:00 JST, so JST-yesterday is
        // 03-09 -- same calendar date on both sides once the +9h is added.
        nowUtc: DateTime.utc(2024, 3, 10, 12),
        expected: DateTime.utc(2024, 3, 9),
      ),
      (
        description:
            'a UTC instant just before midnight that has already rolled '
            'into the next JST day',
        // 2024-03-10 23:00 UTC -> 2024-03-11 08:00 JST: UTC and JST
        // disagree about today's date, so JST-yesterday must be 03-10, not
        // 03-09.
        nowUtc: DateTime.utc(2024, 3, 10, 23),
        expected: DateTime.utc(2024, 3, 10),
      ),
      (
        description: 'a UTC instant just after JST midnight',
        // 2024-03-10 15:30 UTC -> 2024-03-11 00:30 JST.
        nowUtc: DateTime.utc(2024, 3, 10, 15, 30),
        expected: DateTime.utc(2024, 3, 10),
      ),
      (
        description: 'a JST year boundary crossed while UTC is still last year',
        // 2023-12-31 20:00 UTC -> 2024-01-01 05:00 JST.
        nowUtc: DateTime.utc(2023, 12, 31, 20),
        expected: DateTime.utc(2023, 12, 31),
      ),
    ];

    for (final c in cases) {
      test('returns ${c.expected} for ${c.description}', () {
        expect(pixivRankingNewestDate(now: c.nowUtc), c.expected);
      });
    }
  });

  group('ranking date clamping', () {
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final newest = DateTime.utc(2024, 3, 9);
    final earliest = DateTime.utc(2007, 9, 13);

    final cases = [
      (
        description: 'a date after the newest available snapshot',
        input: DateTime.utc(2024, 3, 15),
        expected: newest,
      ),
      (
        description: 'a date before pixiv launched',
        input: DateTime.utc(1999),
        expected: earliest,
      ),
      (
        description: 'a date inside the valid window',
        input: DateTime.utc(2020, 6),
        expected: DateTime.utc(2020, 6),
      ),
      (
        description: 'the newest-available boundary itself',
        input: newest,
        expected: newest,
      ),
      (
        description: 'the earliest-valid boundary itself',
        input: earliest,
        expected: earliest,
      ),
    ];

    for (final c in cases) {
      test('clamps to ${c.expected} for ${c.description}', () {
        expect(clampPixivRankingDate(c.input, now: now), c.expected);
      });
    }
  });

  group('newest-snapshot detection', () {
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final newest = DateTime.utc(2024, 3, 9);

    final cases = [
      (description: 'the newest available date', input: newest, expected: true),
      (
        description: 'a date after the newest available date',
        input: DateTime.utc(2024, 3, 20),
        expected: true,
      ),
      (
        description: 'a date before the newest available date',
        input: DateTime.utc(2024, 3, 8),
        expected: false,
      ),
    ];

    for (final c in cases) {
      test('is ${c.expected} for ${c.description}', () {
        expect(isPixivRankingNewestDate(c.input, now: now), c.expected);
      });
    }
  });

  group('TimeScale to ranking mode mapping', () {
    final cases = [
      (scale: TimeScale.day, expected: PixivRankingMode.day),
      (scale: TimeScale.week, expected: PixivRankingMode.week),
      (scale: TimeScale.month, expected: PixivRankingMode.month),
    ];

    for (final c in cases) {
      test('maps ${c.scale} to ${c.expected}', () {
        expect(pixivRankingModeFrom(c.scale), c.expected);
      });
    }
  });

  group('ranking request date parameter', () {
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final newest = DateTime.utc(2024, 3, 9);

    test('is omitted when the selected date is the newest snapshot', () {
      expect(pixivRankingRequestDateFor(newest, now: now), isNull);
    });

    test('is omitted for a date beyond the newest snapshot too', () {
      expect(
        pixivRankingRequestDateFor(DateTime.utc(2024, 3, 20), now: now),
        isNull,
      );
    });

    test('is present and formatted YYYY-MM-DD for an earlier date', () {
      final result = pixivRankingRequestDateFor(
        DateTime.utc(2020, 6),
        now: now,
      );

      expect(result, isNotNull);
      expect(DateFormat('yyyy-MM-dd').format(result!), '2020-06-01');
    });
  });

  group("the Explore page's selectable ranking date range", () {
    // Pixiv's Explore page passes `kPixivRankingEarliestDate` and
    // `pixivRankingNewestDate()` as the date picker's `firstDate`/
    // `lastDate` (see `_RankingDateStepper` in
    // lib/boorus/pixiv/explore/widgets.dart) rather than the shared
    // `DateTimeSelector`'s own defaults, so today must fall outside that
    // window and its forward arrow must refuse to reach it.
    final now = DateTime.utc(2024, 3, 10, 12); // JST-yesterday: 2024-03-09
    final today = DateTime.utc(2024, 3, 10);

    test("starts at pixiv's launch date", () {
      expect(kPixivRankingEarliestDate, DateTime.utc(2007, 9, 13));
    });

    test('ends at JST-yesterday, one day short of today', () {
      final lastDate = pixivRankingNewestDate(now: now);

      expect(lastDate, DateTime.utc(2024, 3, 9));
      expect(pixivJstToday(now: now), today);
      expect(lastDate.isBefore(today), true);
    });

    test('cannot be stepped forward from the newest snapshot to today', () {
      final lastDate = pixivRankingNewestDate(now: now);

      expect(
        canStepDateTime(
          date: lastDate,
          scale: TimeScale.day,
          forward: true,
          firstDate: kPixivRankingEarliestDate,
          lastDate: lastDate,
        ),
        false,
      );
    });

    test('can still be stepped backward from the newest snapshot', () {
      final lastDate = pixivRankingNewestDate(now: now);

      expect(
        canStepDateTime(
          date: lastDate,
          scale: TimeScale.day,
          forward: false,
          firstDate: kPixivRankingEarliestDate,
          lastDate: lastDate,
        ),
        true,
      );
    });
  });

  group('ranking page offset formula', () {
    final cases = [
      (page: 1, expected: 0),
      (page: 2, expected: 30),
      (page: 5, expected: 120),
    ];

    for (final c in cases) {
      test('offset is ${c.expected} for page ${c.page}', () {
        expect(pixivRankingOffsetFor(c.page), c.expected);
      });
    }
  });

  group('switching the top-level feed selector', () {
    test('keeps Ranking mode/date only while the kind stays Ranking', () {
      final ranking = PixivRankingFeed(
        mode: PixivRankingMode.dayR18,
        date: DateTime.utc(2020),
      );

      // Hopping to Following, then to Recommended, then back to Ranking:
      // the mode/date must not survive the trip through feeds that have
      // nowhere to carry them.
      final toFollowing = pixivDefaultFeedFor(
        PixivExploreFeedKind.following,
        current: ranking,
        newestRankingDate: DateTime.utc(2024),
      );
      final toRecommended = pixivDefaultFeedFor(
        PixivExploreFeedKind.recommended,
        current: toFollowing,
        newestRankingDate: DateTime.utc(2024),
      );
      final backToRanking = pixivDefaultFeedFor(
        PixivExploreFeedKind.ranking,
        current: toRecommended,
        newestRankingDate: DateTime.utc(2024),
      );

      expect(toFollowing, isA<PixivFollowingFeed>());
      expect(toRecommended, isA<PixivRecommendedFeed>());
      expect(
        backToRanking,
        PixivRankingFeed(mode: PixivRankingMode.day, date: DateTime.utc(2024)),
      );
    });

    test('returns the same instance when the kind is already selected', () {
      final ranking = PixivRankingFeed(
        mode: PixivRankingMode.weekR18g,
        date: DateTime.utc(2022, 5, 5),
      );

      final result = pixivDefaultFeedFor(
        PixivExploreFeedKind.ranking,
        current: ranking,
        newestRankingDate: DateTime.utc(2024),
      );

      expect(result, ranking);
    });

    test('remembers the follow restrict when re-selecting Following', () {
      const following = PixivFollowingFeed(
        restrict: PixivFollowRestrict.private,
      );

      final result = pixivDefaultFeedFor(
        PixivExploreFeedKind.following,
        current: following,
        newestRankingDate: DateTime.utc(2024),
      );

      expect(result, following);
    });
  });

  group('R-18 warning', () {
    final cases = [
      (mode: PixivRankingMode.day, xRestrict: 0, shouldWarn: false),
      (mode: PixivRankingMode.dayR18, xRestrict: 0, shouldWarn: true),
      (mode: PixivRankingMode.dayR18, xRestrict: 1, shouldWarn: false),
      (mode: PixivRankingMode.dayR18, xRestrict: 2, shouldWarn: false),
      (mode: PixivRankingMode.weekR18g, xRestrict: 0, shouldWarn: true),
      (mode: PixivRankingMode.weekR18g, xRestrict: 1, shouldWarn: true),
      (mode: PixivRankingMode.weekR18g, xRestrict: 2, shouldWarn: false),
      (mode: PixivRankingMode.day, xRestrict: null, shouldWarn: false),
      (mode: PixivRankingMode.dayR18, xRestrict: null, shouldWarn: false),
      (mode: PixivRankingMode.weekR18g, xRestrict: null, shouldWarn: false),
    ];

    for (final c in cases) {
      test(
        '${c.shouldWarn ? 'warns' : 'does not warn'} for '
        '${c.mode} with account xRestrict ${c.xRestrict}',
        () {
          final feed = PixivRankingFeed(mode: c.mode, date: DateTime.utc(2024));

          expect(
            pixivShouldWarnXRestrict(feed, c.xRestrict),
            c.shouldWarn,
          );
        },
      );
    }

    test('never warns for Following or Recommended, regardless of level', () {
      for (final xRestrict in [0, 1, 2, null]) {
        expect(
          pixivShouldWarnXRestrict(const PixivFollowingFeed(), xRestrict),
          false,
        );
        expect(
          pixivShouldWarnXRestrict(const PixivRecommendedFeed(), xRestrict),
          false,
        );
      }
    });
  });

  group('storing the account x_restrict level alongside other metadata', () {
    test('survives a round trip through the passHash field', () {
      final restored = PixivExtraData.fromPassHash(
        const PixivExtraData(userId: '1', xRestrict: 1).toPassHash(),
      );

      expect(restored.xRestrict, 1);
    });

    final malformed = [
      (passHash: null, reason: 'a missing value'),
      (passHash: '', reason: 'an empty value'),
      (passHash: 'not json at all', reason: 'a value that is not json'),
      (
        passHash: '{"xRestrict": "not a number"}',
        reason: 'a wrongly typed field',
      ),
    ];

    for (final c in malformed) {
      test('falls back to null for ${c.reason}', () {
        expect(PixivExtraData.fromPassHash(c.passHash).xRestrict, isNull);
      });
    }
  });

  group('each feed descriptor resolves to the matching client call', () {
    late _RecordingAdapter adapter;
    late PixivExploreRepository repo;

    setUp(() {
      adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
        ..httpClientAdapter = adapter;
      repo = PixivExploreRepository(
        client: PixivClient(dio: dio, accessToken: 'token'),
      );
    });

    test('Ranking calls the ranking endpoint with its mode and date', () async {
      await repo
          .getPosts(
            feed: PixivRankingFeed(
              mode: PixivRankingMode.weekR18Manga,
              date: DateTime.utc(2022, 4, 4),
            ),
            page: 2,
            now: DateTime.utc(2024),
          )
          .run();

      final request = adapter.lastRequest!;
      expect(request.path, '/v1/illust/ranking');
      expect(request.queryParameters['mode'], 'week_r18_manga');
      expect(request.queryParameters['date'], '2022-04-04');
      expect(request.queryParameters['offset'], 30);
    });

    test(
      'Ranking omits the date parameter for the newest snapshot',
      () async {
        final now = DateTime.utc(2024, 3, 10, 12);
        final newest = DateTime.utc(2024, 3, 9);

        await repo
            .getPosts(
              feed: PixivRankingFeed(mode: PixivRankingMode.day, date: newest),
              page: 1,
              now: now,
            )
            .run();

        expect(
          adapter.lastRequest!.queryParameters.containsKey('date'),
          false,
        );
      },
    );

    test(
      'Following calls the follow endpoint with its restrict value',
      () async {
        await repo
            .getPosts(
              feed: const PixivFollowingFeed(
                restrict: PixivFollowRestrict.private,
              ),
              page: 3,
            )
            .run();

        final request = adapter.lastRequest!;
        expect(request.path, '/v2/illust/follow');
        expect(request.queryParameters['restrict'], 'private');
        expect(request.queryParameters['offset'], 60);
      },
    );

    test('Recommended calls the recommended endpoint', () async {
      await repo.getPosts(feed: const PixivRecommendedFeed(), page: 1).run();

      final request = adapter.lastRequest!;
      expect(request.path, '/v1/illust/recommended');
      expect(request.queryParameters['offset'], 0);
    });
  });
}

/// Records the last request that reached the wire and answers with an
/// empty, exhausted (`next_url: null`) page — enough for the repository's
/// param-mapping to be observed without a real server.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;

    return ResponseBody.fromString(
      jsonEncode({'illusts': <dynamic>[], 'next_url': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
