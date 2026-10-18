import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/search/following_topics/src/refresh/search_refresh_fetch_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final item in [
    (
      engine: BooruType.danbooru,
      url: 'https://danbooru.donmai.us',
      limit: 200,
      delta: true,
    ),
    (
      engine: BooruType.gelbooru,
      url: 'https://gelbooru.com',
      limit: 100,
      delta: false,
    ),
    (
      engine: BooruType.gelbooruV2,
      url: 'https://rule34.xxx',
      limit: 1000,
      delta: false,
    ),
    (engine: BooruType.e621, url: 'https://e621.net', limit: 320, delta: false),
    (
      engine: BooruType.danbooru,
      url: 'https://unknown.example',
      limit: 50,
      delta: false,
    ),
  ]) {
    test('plans a bounded site request for ${item.url}', () {
      final plan = planSearchRefreshFetch(
        booruType: item.engine,
        siteUrl: item.url,
        query: 'artist_name',
        afterPostId: 1234,
      );
      expect(plan.limit, item.limit);
      expect(plan.delta, item.delta);
      expect(
        plan.query,
        item.delta ? 'artist_name id:>1234 order:id_asc' : 'artist_name',
      );
    });
  }

  for (final url in [
    'https://danbooru.donmai.us/custom',
    'https://danbooru.donmai.us:8443',
    'https://danbooru.donmai.us.example',
    'https://unknown.example',
    'not a URL',
  ]) {
    test('custom installations keep conservative transport bounds: $url', () {
      final plan = planSearchRefreshFetch(
        booruType: BooruType.danbooru,
        siteUrl: url,
        query: 'cat',
        afterPostId: 123,
      );
      expect(plan.limit, 50);
      expect(plan.delta, isFalse);
    });
  }

  for (final query in [
    'cat id:<400',
    'cat -id:20',
    'cat date:today',
    'cat age:<1d',
    'cat ordpool:1',
    'cat random:50',
    'cat limit:10',
    '(cat or dog)',
    'cat order:score',
    'cat order:id',
    'cat ~dog',
  ]) {
    test('keeps constrained query on snapshot path: $query', () {
      final plan = planSearchRefreshFetch(
        booruType: BooruType.danbooru,
        siteUrl: 'https://danbooru.donmai.us',
        query: query,
        afterPostId: 123,
      );
      expect(plan.delta, isFalse);
      expect(plan.query, query);
    });
  }

  for (final query in [
    'zenless_zone_zero 1girl',
    'cat dog rating:s',
    '-cat dog',
    'cat* dog',
  ]) {
    test('does not spend an extra counted term for $query', () {
      final plan = planSearchRefreshFetch(
        booruType: BooruType.danbooru,
        siteUrl: 'https://danbooru.donmai.us',
        query: query,
        afterPostId: 123,
      );
      expect(plan.delta, isFalse);
      expect(plan.query, query);
    });
  }
  for (final query in ['cat rating:s', 'cat cat', 'cat dog order:id_desc']) {
    test('retains safe deltas when ordering fits the query budget: $query', () {
      final plan = planSearchRefreshFetch(
        booruType: BooruType.danbooru,
        siteUrl: 'https://danbooru.donmai.us',
        query: query,
        afterPostId: 123,
      );
      expect(plan.delta, isTrue);
      expect(plan.query, contains('id:>123 order:id_asc'));
    });
  }

  test(
    'does not add a conflicting id filter or truncate the baseline query',
    () {
      final ordinary = planSearchRefreshFetch(
        booruType: BooruType.danbooru,
        siteUrl: 'https://danbooru.donmai.us',
        query: 'artist_name id:<400',
        afterPostId: 123,
      );
      final baseline = planSearchRefreshFetch(
        booruType: BooruType.danbooru,
        siteUrl: 'https://danbooru.donmai.us',
        query: 'artist_name',
        afterPostId: 123,
        requireFullSnapshot: true,
      );
      expect(ordinary.delta, false);
      expect(ordinary.query, 'artist_name id:<400');
      expect(baseline.delta, false);
      expect(baseline.query, 'artist_name');
    },
  );
}
