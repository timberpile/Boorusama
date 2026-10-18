// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../settings/providers.dart';
import '../types/topic_feed_member_sort.dart';

final topicFeedMemberSortProvider =
    NotifierProvider<TopicFeedMemberSortNotifier, TopicFeedMemberSort>(
      TopicFeedMemberSortNotifier.new,
    );

class TopicFeedMemberSortNotifier extends Notifier<TopicFeedMemberSort> {
  Future<void> _selectionTail = Future.value();

  @override
  TopicFeedMemberSort build() => TopicFeedMemberSort.parse(
    ref.watch(settingsProvider).topicFeedMemberSort,
  );

  Future<bool> select(TopicFeedMemberSort sort) {
    final result = _selectionTail.then((_) async {
      try {
        return await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(topicFeedMemberSort: sort.name),
            );
      } catch (_) {
        return false;
      }
    });
    _selectionTail = result.then((_) {});
    return result;
  }
}
