import 'following_topic.dart';

enum FollowingTopicSort {
  manual,
  nameAsc,
  updatesFirst,
  lastPostOldest;

  static FollowingTopicSort parse(Object? value) => switch (value) {
    'nameAsc' => nameAsc,
    'updatesFirst' => updatesFirst,
    'lastPostOldest' => lastPostOldest,
    _ => manual,
  };
}

extension FollowingTopicLastPost on FollowingTopic {
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

List<FollowingTopic> sortFollowingTopics(
  List<FollowingTopic> items,
  FollowingTopicSort sort,
) {
  if (sort == FollowingTopicSort.manual) return List.unmodifiable(items);

  final indexed = items.indexed.toList()
    ..sort((left, right) {
      if (sort == FollowingTopicSort.nameAsc) {
        final order = left.$2.displayName.toLowerCase().compareTo(
          right.$2.displayName.toLowerCase(),
        );
        return order != 0 ? order : left.$1.compareTo(right.$1);
      }
      if (sort == FollowingTopicSort.updatesFirst) {
        if (left.$2.hasNewPosts != right.$2.hasNewPosts) {
          return left.$2.hasNewPosts ? -1 : 1;
        }
      }
      final dateOrder = switch ((left.$2.lastPostAt, right.$2.lastPostAt)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final leftDate?, final rightDate?) => switch (sort) {
          FollowingTopicSort.updatesFirst => rightDate.compareTo(leftDate),
          FollowingTopicSort.lastPostOldest => leftDate.compareTo(rightDate),
          FollowingTopicSort.manual || FollowingTopicSort.nameAsc => 0,
        },
      };
      return dateOrder != 0 ? dateOrder : left.$1.compareTo(right.$1);
    });
  return List.unmodifiable(indexed.map((entry) => entry.$2));
}
