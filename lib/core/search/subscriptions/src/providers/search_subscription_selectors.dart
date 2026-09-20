// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
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

final pinnedSearchTrackingSupportedProvider =
    Provider.family<bool, BooruConfigAuth>(
      (ref, config) =>
          ref
              .watch(booruRepoProvider(config))
              ?.searchRefreshQueryAdapter(config)
              .isSupported ??
          false,
    );

final folderPinnedSearchesProvider =
    Provider.family<
      AsyncValue<List<SearchSubscription>>,
      ({int profileId, String? folderId})
    >((ref, group) {
      final folders =
          ref
              .watch(searchSubscriptionsProvider)
              .valueOrNull
              ?.folders
              .where((f) => f.profileId == group.profileId)
              .toList() ??
          [];
      final membership = {
        for (final folder in folders)
          for (final id in folder.searchIds) id: folder.id,
      };
      return ref
          .watch(profilePinnedSearchesProvider(group.profileId))
          .whenData(
            (items) => List.unmodifiable(
              items.where((item) => membership[item.id] == group.folderId),
            ),
          );
    });
