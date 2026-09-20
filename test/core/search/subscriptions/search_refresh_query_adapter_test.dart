// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/danbooru_repository.dart';
import 'package:boorusama/boorus/szurubooru/szurubooru_repository.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';

void main() {
  test('Danbooru and Szurubooru do not add sort terms to refresh queries', () {
    final danbooru = Provider((ref) => DanbooruRepository(ref: ref));
    final szurubooru = Provider((ref) => SzurubooruRepository(ref: ref));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container
          .read(danbooru)
          .searchRefreshQueryAdapter(BooruConfig.empty.auth)
          .plan('-video -touhou', after: null),
      const SupportedSearchRefreshQueryPlan(query: '-video -touhou'),
    );
    expect(
      container
          .read(szurubooru)
          .searchRefreshQueryAdapter(BooruConfig.empty.auth)
          .plan('cat', after: null),
      const SupportedSearchRefreshQueryPlan(query: 'cat'),
    );
  });
  test('keeps Danbooru default ordering without consuming a search term', () {
    const adapter = OrderedSearchRefreshQueryAdapter(
      orderingToken: null,
      acceptedOrderingTokens: {
        'order:created_at',
        'order:id',
        'order:id_desc',
      },
    );
    expect(
      adapter.plan('-video -touhou', after: null),
      const SupportedSearchRefreshQueryPlan(query: '-video -touhou'),
    );
    expect(
      adapter.plan('-video -touhou order:id', after: null),
      const SupportedSearchRefreshQueryPlan(query: '-video -touhou'),
    );
  });
  final checkpoint = DateTime.utc(2026, 9);
  const adapter = DefaultSearchRefreshQueryAdapter();

  const ordered = OrderedSearchRefreshQueryAdapter(
    orderingToken: null,
    acceptedOrderingTokens: {'sort:creation-time', 'sort:creation-date'},
    unsupportedMetatags: {'random', 'ordpool'},
  );
  for (final c in [
    (query: 'cat rating:safe', result: 'cat rating:safe'),
    (query: 'cat sort:creation-time', result: 'cat'),
    (query: 'cat sort:creation-date', result: 'cat'),
  ]) {
    test(
      'checks ${c.query} using default order without changing filters',
      () {
        expect(
          ordered.plan(c.query, after: null),
          SupportedSearchRefreshQueryPlan(query: c.result),
        );
      },
    );
  }
  for (final query in [
    'cat order:score',
    'cat sort=random',
    'random:10',
    'ordpool:12',
  ]) {
    test('declines unsafe chronological checking for $query', () {
      expect(
        ordered.plan(query, after: null),
        isA<UnsupportedSearchRefreshQueryPlan>(),
      );
    });
  }

  test('keeps an ordinary query unchanged', () {
    final plan = adapter.plan('cat rating:safe', after: checkpoint);

    expect(plan, isA<SupportedSearchRefreshQueryPlan>());
    expect((plan as SupportedSearchRefreshQueryPlan).query, 'cat rating:safe');
  });

  final unsupportedQueries = [
    'cat order:score',
    'cat sort:favorites',
    'order_by=random',
  ];
  for (final query in unsupportedQueries) {
    test('rejects the non-chronological query $query', () {
      expect(
        adapter.plan(query, after: checkpoint),
        isA<UnsupportedSearchRefreshQueryPlan>(),
      );
    });
  }

  test('does not reject a normal tag containing order', () {
    final plan = adapter.plan('orderly cat', after: checkpoint);

    expect(plan, isA<SupportedSearchRefreshQueryPlan>());
  });
}
