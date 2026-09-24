import 'search_subscription.dart';

enum PinnedSearchSort { manual, lastPostNewest, lastPostOldest }

extension SearchSubscriptionLastPost on SearchSubscription {
  DateTime? get lastPostAt {
    DateTime? latest;
    for (final preview in previews) {
      latest = switch ((latest, preview.postCreatedAt)) {
        (null, final timestamp?) => timestamp,
        (final current?, final timestamp?) when timestamp.isAfter(current) =>
          timestamp,
        _ => latest,
      };
    }
    return latest;
  }
}

List<SearchSubscription> sortPinnedSearches(
  List<SearchSubscription> items,
  PinnedSearchSort sort,
) {
  if (sort == PinnedSearchSort.manual) return List.unmodifiable(items);

  final indexed = items.indexed.toList()
    ..sort((left, right) {
      final dateOrder = switch ((left.$2.lastPostAt, right.$2.lastPostAt)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final leftDate?, final rightDate?) => switch (sort) {
          PinnedSearchSort.lastPostNewest => rightDate.compareTo(leftDate),
          PinnedSearchSort.lastPostOldest => leftDate.compareTo(rightDate),
          PinnedSearchSort.manual => 0,
        },
      };
      return dateOrder != 0 ? dateOrder : left.$1.compareTo(right.$1);
    });
  return List.unmodifiable(indexed.map((entry) => entry.$2));
}
