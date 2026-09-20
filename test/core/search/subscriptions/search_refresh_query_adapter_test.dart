// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/search/subscriptions/src/refresh/search_refresh_query_adapter.dart';

void main() {
  final checkpoint = DateTime.utc(2026, 9);
  const adapter = DefaultSearchRefreshQueryAdapter();

  const ordered = OrderedSearchRefreshQueryAdapter(
    orderingToken: 'order:created_at',
    acceptedOrderingTokens: {'order:created_at', 'order:id'},
    unsupportedMetatags: {'random', 'ordpool'},
  );
  for (final c in [
    (query: 'cat rating:safe', result: 'cat rating:safe order:created_at'),
    (query: 'cat order:id', result: 'cat order:created_at'),
    (query: 'cat order:created_at', result: 'cat order:created_at'),
  ]) {
    test(
      'checks ${c.query} using canonical upload ordering without changing filters',
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
