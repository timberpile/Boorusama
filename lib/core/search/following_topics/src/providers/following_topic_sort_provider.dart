// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../settings/providers.dart';
import '../types/following_topic_sort.dart';

final followingTopicSortProvider =
    NotifierProvider<FollowingTopicSortNotifier, FollowingTopicSort>(
      FollowingTopicSortNotifier.new,
    );

class FollowingTopicSortNotifier extends Notifier<FollowingTopicSort> {
  Future<void> _selectionTail = Future.value();

  @override
  FollowingTopicSort build() => FollowingTopicSort.parse(
    ref.watch(settingsProvider).followingTopicSort,
  );

  Future<bool> select(FollowingTopicSort sort) {
    final result = _selectionTail.then((_) async {
      try {
        return await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(followingTopicSort: sort.name),
            );
      } catch (_) {
        return false;
      }
    });
    _selectionTail = result.then((_) {});
    return result;
  }
}
