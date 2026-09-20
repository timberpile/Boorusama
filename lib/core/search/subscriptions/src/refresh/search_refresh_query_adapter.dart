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
  bool get isSupported;

  SearchRefreshQueryPlan plan(String query, {required DateTime? after});
}

class DefaultSearchRefreshQueryAdapter implements SearchRefreshQueryAdapter {
  const DefaultSearchRefreshQueryAdapter();

  @override
  bool get isSupported => true;

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

class UnsupportedSearchRefreshQueryAdapter
    implements SearchRefreshQueryAdapter {
  const UnsupportedSearchRefreshQueryAdapter();

  @override
  bool get isSupported => false;

  @override
  SearchRefreshQueryPlan plan(String query, {required DateTime? after}) =>
      const UnsupportedSearchRefreshQueryPlan();
}

class OrderedSearchRefreshQueryAdapter
    extends DefaultSearchRefreshQueryAdapter {
  const OrderedSearchRefreshQueryAdapter({
    required this.orderingToken,
    this.acceptedOrderingTokens = const {},
    this.unsupportedMetatags = const {},
  });

  final String? orderingToken;
  final Set<String> acceptedOrderingTokens;
  final Set<String> unsupportedMetatags;

  @override
  SearchRefreshQueryPlan plan(String query, {required DateTime? after}) {
    final terms = query.trim().split(RegExp(r'\s+'));
    final filters = <String>[];
    for (final term in terms) {
      final key = DefaultSearchRefreshQueryAdapter._metatag
          .firstMatch(term)
          ?.group(1)
          ?.toLowerCase();
      if (unsupportedMetatags.contains(key)) {
        return const UnsupportedSearchRefreshQueryPlan();
      }
      if (DefaultSearchRefreshQueryAdapter._orderingMetatagKeys.contains(key)) {
        if (!acceptedOrderingTokens.contains(term.toLowerCase())) {
          return const UnsupportedSearchRefreshQueryPlan();
        }
      } else if (term.isNotEmpty) {
        filters.add(term);
      }
    }
    return SupportedSearchRefreshQueryPlan(
      query: [...filters, ?orderingToken].join(' '),
    );
  }
}
