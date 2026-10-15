import 'following_topic.dart';
import 'following_topic_sort.dart';

enum TopicFeedMemberSort {
  addedDate,
  newestFirst,
  oldestFirst,
  lastRefresh;

  static TopicFeedMemberSort parse(Object? value) => switch (value) {
    'newestFirst' => newestFirst,
    'oldestFirst' => oldestFirst,
    'lastRefresh' => lastRefresh,
    _ => addedDate,
  };
}

List<FollowingTopic> sortTopicFeedMembers(
  List<FollowingTopic> membersInAdditionOrder,
  TopicFeedMemberSort sort,
) {
  if (sort == TopicFeedMemberSort.addedDate) {
    return List.unmodifiable(membersInAdditionOrder);
  }
  final indexed = membersInAdditionOrder.indexed.toList()
    ..sort((left, right) {
      final refreshOrder = sort == TopicFeedMemberSort.lastRefresh;
      final dates = switch ((
        refreshOrder ? left.$2.lastSuccessfulCheckAt : left.$2.lastPostAt,
        refreshOrder ? right.$2.lastSuccessfulCheckAt : right.$2.lastPostAt,
      )) {
        (null, null) => 0,
        (null, _) => refreshOrder ? -1 : 1,
        (_, null) => refreshOrder ? 1 : -1,
        (final a?, final b?) =>
          sort == TopicFeedMemberSort.newestFirst
              ? b.compareTo(a)
              : a.compareTo(b),
      };
      return dates == 0 ? left.$1.compareTo(right.$1) : dates;
    });
  return List.unmodifiable(indexed.map((e) => e.$2));
}
