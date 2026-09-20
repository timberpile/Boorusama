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
        final items =
            state.subscriptions
                .where(
                  (item) => item.profileId == profileId && item.feedId == null,
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

final organizedPinnedSearchesProvider =
    Provider.family<AsyncValue<List<SearchSubscription>>, String?>(
      (ref, folderId) => ref.watch(searchSubscriptionsProvider).whenData((
        state,
      ) {
        final profiles = ref
            .watch(booruConfigProvider)
            .map((config) => config.id)
            .toSet();
        final byId = {
          for (final search in state.subscriptions)
            if (search.feedId == null && profiles.contains(search.profileId))
              search.id: search,
        };
        final ids = folderId == null
            ? state.organization.homeSearchIds
            : state.organization.folders
                  .singleWhere((folder) => folder.id == folderId)
                  .searchIds;
        return List.unmodifiable([
          for (final id in ids)
            if (byId[id] case final search?) search,
        ]);
      }),
    );

final pinnedSearchHasNewPostsProvider = Provider<bool>((ref) {
  final profiles = ref.watch(booruConfigProvider).map((c) => c.id).toSet();
  return ref
          .watch(searchSubscriptionsProvider)
          .valueOrNull
          ?.subscriptions
          .any(
            (s) =>
                s.feedId == null &&
                profiles.contains(s.profileId) &&
                s.hasNewPosts,
          ) ??
      false;
});
