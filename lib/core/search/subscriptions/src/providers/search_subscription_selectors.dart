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

final profilePinnedSearchUnreadCountProvider = Provider.family<int, int>((
  ref,
  profileId,
) {
  return ref
          .watch(profilePinnedSearchesProvider(profileId))
          .valueOrNull
          ?.fold<int>(0, (total, item) => total + item.unreadCount) ??
      0;
});
