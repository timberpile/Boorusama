import 'search_subscription.dart';
import 'pinned_search_sort.dart';

enum FollowingFeedMemberSort {
  addedDate,
  newestFirst,
  oldestFirst;

  static FollowingFeedMemberSort parse(Object? value) => switch (value) {
    'newestFirst' => newestFirst,
    'oldestFirst' => oldestFirst,
    _ => addedDate,
  };
}

List<SearchSubscription> sortFollowingFeedMembers(
  List<SearchSubscription> membersInAdditionOrder,
  FollowingFeedMemberSort sort,
) {
  if (sort == FollowingFeedMemberSort.addedDate) {
    return List.unmodifiable(membersInAdditionOrder);
  }
  final indexed = membersInAdditionOrder.indexed.toList()
    ..sort((left, right) {
      final dates = switch ((left.$2.lastPostAt, right.$2.lastPostAt)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final a?, final b?) =>
          sort == FollowingFeedMemberSort.newestFirst
              ? b.compareTo(a)
              : a.compareTo(b),
      };
      return dates == 0 ? left.$1.compareTo(right.$1) : dates;
    });
  return List.unmodifiable(indexed.map((e) => e.$2));
}
