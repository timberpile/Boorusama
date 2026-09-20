// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../types/search_subscription.dart';
import 'search_subscriptions_notifier.dart';

final profilePinnedSearchesProvider =
    Provider.family<AsyncValue<List<SearchSubscription>>, int>((
      ref,
      profileId,
    ) {
      return ref.watch(searchSubscriptionsProvider).whenData((state) {
        final items =
            state.subscriptions
                .where((item) => item.profileId == profileId)
                .toList()
              ..sort((a, b) => a.position.compareTo(b.position));
        return List.unmodifiable(items);
      });
    });

final profilePinnedSearchHasNewPostsProvider = Provider.family<bool, int>((
  ref,
  profileId,
) {
  return ref
          .watch(profilePinnedSearchesProvider(profileId))
          .valueOrNull
          ?.any((item) => item.hasNewPosts) ??
      false;
});
