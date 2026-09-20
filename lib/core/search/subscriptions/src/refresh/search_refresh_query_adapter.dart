// Package imports:
import 'package:equatable/equatable.dart';

sealed class SearchRefreshQueryPlan extends Equatable {
  const SearchRefreshQueryPlan();
}

final class SupportedSearchRefreshQueryPlan extends SearchRefreshQueryPlan {
  const SupportedSearchRefreshQueryPlan({
    required this.query,
  });

  final String query;

  @override
  List<Object?> get props => [query];
}

final class UnsupportedSearchRefreshQueryPlan extends SearchRefreshQueryPlan {
  const UnsupportedSearchRefreshQueryPlan();

  @override
  List<Object?> get props => const [];
}

abstract interface class SearchRefreshQueryAdapter {
  SearchRefreshQueryPlan plan(String query, {required DateTime? after});
}

class DefaultSearchRefreshQueryAdapter implements SearchRefreshQueryAdapter {
  const DefaultSearchRefreshQueryAdapter();

  static const _orderingMetatagKeys = {'order', 'order_by', 'sort'};
  static final _metatag = RegExp('^([^:=]+)[:=]');

  @override
  SearchRefreshQueryPlan plan(String query, {required DateTime? after}) {
    final requestsOrdering = query.split(RegExp(r'\s+')).any((token) {
      final key = _metatag.firstMatch(token)?.group(1)?.toLowerCase();
      return key != null && _orderingMetatagKeys.contains(key);
    });

    return switch (requestsOrdering) {
      true => const UnsupportedSearchRefreshQueryPlan(),
      false => SupportedSearchRefreshQueryPlan(query: query),
    };
  }
}
