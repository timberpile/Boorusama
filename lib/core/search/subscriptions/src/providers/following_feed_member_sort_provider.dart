// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../settings/providers.dart';
import '../types/following_feed_member_sort.dart';

final followingFeedMemberSortProvider =
    NotifierProvider<FollowingFeedMemberSortNotifier, FollowingFeedMemberSort>(
      FollowingFeedMemberSortNotifier.new,
    );

class FollowingFeedMemberSortNotifier
    extends Notifier<FollowingFeedMemberSort> {
  Future<void> _selectionTail = Future.value();

  @override
  FollowingFeedMemberSort build() => FollowingFeedMemberSort.parse(
    ref.watch(settingsProvider).followingFeedMemberSort,
  );

  Future<bool> select(FollowingFeedMemberSort sort) {
    final result = _selectionTail.then((_) async {
      try {
        return await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) =>
                  settings.copyWith(followingFeedMemberSort: sort.name),
            );
      } catch (_) {
        return false;
      }
    });
    _selectionTail = result.then((_) {});
    return result;
  }
}
