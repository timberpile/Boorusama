// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../types/search_subscription.dart';
import 'search_subscriptions_notifier.dart';

final profilePinnedSearchesProvider =
    Provider.family<AsyncValue<List<SearchSubscription>>, int>((
      ref,
      profileId,
    ) {
      return ref.watch(searchSubscriptionsProvider).whenData((state) {
        final internalIds = {
          for (final feed in state.feeds) ...feed.sourceIds,
        };
        final items =
            state.subscriptions
                .where(
                  (item) =>
                      item.profileId == profileId &&
                      !internalIds.contains(item.id),
                )
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

final organizedPinnedSearchesProvider =
    Provider.family<AsyncValue<List<SearchSubscription>>, String?>(
      (ref, folderId) => ref.watch(searchSubscriptionsProvider).whenData((
        state,
      ) {
        final profiles = ref
            .watch(booruConfigProvider)
            .map((config) => config.id)
            .toSet();
        final internalIds = {
          for (final feed in state.feeds) ...feed.sourceIds,
        };
        final byId = {
          for (final search in state.subscriptions)
            if (!internalIds.contains(search.id) &&
                profiles.contains(search.profileId))
              search.id: search,
        };
        final ids = folderId == null
            ? state.organization.homeSearchIds
            : state.organization.folders
                  .singleWhere((folder) => folder.id == folderId)
                  .searchIds;
        return List.unmodifiable([
          for (final id in ids) ?byId[id],
        ]);
      }),
    );

final pinnedSearchHasNewPostsProvider = Provider<bool>((ref) {
  final profiles = ref.watch(booruConfigProvider).map((c) => c.id).toSet();
  final state = ref.watch(searchSubscriptionsProvider).valueOrNull;
  if (state == null) return false;
  final internalIds = {for (final feed in state.feeds) ...feed.sourceIds};
  return state.subscriptions.any(
    (search) =>
        !internalIds.contains(search.id) &&
        profiles.contains(search.profileId) &&
        search.hasNewPosts,
  );
});

final followingFeedHasNewPostsProvider = Provider<bool>((ref) {
  final profiles = ref
      .watch(booruConfigProvider)
      .map((config) => config.id)
      .toSet();
  final state = ref.watch(searchSubscriptionsProvider).valueOrNull;
  if (state == null) return false;
  final newSearchIds = {
    for (final search in state.subscriptions)
      if (search.hasNewPosts) search.id,
  };
  return state.feeds.any(
    (feed) =>
        profiles.contains(feed.profileId) &&
        feed.sourceIds.any(newSearchIds.contains),
  );
});
