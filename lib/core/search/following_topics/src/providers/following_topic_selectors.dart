// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

// Project imports:
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../types/following_topic.dart';
import '../types/following_topic_sort.dart';
import 'following_topic_sort_provider.dart';
import 'following_topics_notifier.dart';

final profileFollowingTopicsProvider =
    Provider.family<AsyncValue<List<FollowingTopic>>, String>((
      ref,
      profileId,
    ) {
      return ref.watch(followingTopicsProvider).whenData((state) {
        final folderIds = state.organization.folders
            .map((folder) => folder.id)
            .toSet();
        final internalIds = {
          for (final feed in state.feeds)
            if (!folderIds.contains(feed.id)) ...feed.sourceIds,
        };
        final items =
            state.topics
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

final followedTopicCountProvider =
    Provider.family<int, ({String profileId, String query})>((ref, key) {
      return ref
              .watch(matchingFollowingTopicsProvider(key))
              .valueOrNull
              ?.length ??
          0;
    });

final matchingFollowingTopicsProvider =
    Provider.family<
      AsyncValue<List<FollowingTopicMatch>>,
      ({String profileId, String query})
    >((ref, key) {
      return ref
          .watch(followingTopicsProvider)
          .whenData(
            (state) => selectMatchingFollowingTopics(
              state,
              profileId: key.profileId,
              query: key.query,
            ),
          );
    });

final class FollowingTopicMatch {
  const FollowingTopicMatch({
    required this.topic,
    required this.folderId,
    required this.folderPath,
  });

  final FollowingTopic topic;
  final String? folderId;
  final String folderPath;
}

List<FollowingTopicMatch> selectMatchingFollowingTopics(
  FollowingTopicsState state, {
  required String profileId,
  required String query,
}) {
  final identity = normalizeSearchIdentity(query);
  if (identity.isEmpty) return const [];
  final topics = {for (final topic in state.topics) topic.id: topic};
  final tree = state.organization.tree;
  final matches = <FollowingTopicMatch>[];
  for (final placement in state.organization.placements) {
    final topic = topics[placement.itemId];
    if (topic == null ||
        topic.profileId != profileId ||
        normalizeSearchIdentity(topic.query) != identity) {
      continue;
    }
    matches.add(
      FollowingTopicMatch(
        topic: topic,
        folderId: placement.folderId,
        folderPath: tree.path(placement.folderId),
      ),
    );
  }
  return List.unmodifiable(matches);
}

FollowingTopicMatch? resolveOriginatingFollowingTopic(
  List<FollowingTopicMatch> matches,
  String? originatingTopicId,
) => originatingTopicId == null
    ? null
    : matches
          .where((match) => match.topic.id == originatingTopicId)
          .firstOrNull;

final profileFollowingTopicHasNewPostsProvider = Provider.family<bool, String>((
  ref,
  profileId,
) {
  return ref
          .watch(profileFollowingTopicsProvider(profileId))
          .valueOrNull
          ?.any((item) => item.hasNewPosts) ??
      false;
});

final followingTopicTrackingSupportedProvider =
    Provider.family<bool, BooruConfigAuth>(
      (ref, config) =>
          ref
              .watch(booruRepoProvider(config))
              ?.searchRefreshQueryAdapter(config)
              .isSupported ??
          false,
    );

final organizedFollowingTopicsProvider =
    Provider.family<AsyncValue<List<FollowingTopic>>, String?>(
      (ref, folderId) => ref.watch(followingTopicsProvider).whenData((
        state,
      ) {
        final profiles = ref
            .watch(booruConfigProvider)
            .map((config) => config.id)
            .toSet();
        final folderIds = state.organization.folders
            .map((folder) => folder.id)
            .toSet();
        final internalIds = {
          for (final feed in state.feeds)
            if (!folderIds.contains(feed.id)) ...feed.sourceIds,
        };
        final byId = {
          for (final search in state.topics)
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

final visibleFollowingTopicsProvider =
    Provider.family<AsyncValue<List<FollowingTopic>>, String?>(
      (ref, folderId) => ref
          .watch(organizedFollowingTopicsProvider(folderId))
          .whenData(
            (items) => sortFollowingTopics(
              items,
              ref.watch(followingTopicSortProvider),
            ),
          ),
    );

final followingTopicHasNewPostsProvider = Provider<bool>((ref) {
  final profiles = ref.watch(booruConfigProvider).map((c) => c.id).toSet();
  final state = ref.watch(followingTopicsProvider).valueOrNull;
  if (state == null) return false;
  final folderIds = state.organization.folders
      .map((folder) => folder.id)
      .toSet();
  final internalIds = {
    for (final feed in state.feeds)
      if (!folderIds.contains(feed.id)) ...feed.sourceIds,
  };
  return state.topics.any(
    (search) =>
        !internalIds.contains(search.id) &&
        profiles.contains(search.profileId) &&
        search.hasNewPosts,
  );
});

final topicFeedHasNewPostsProvider = Provider<bool>((ref) {
  final profiles = ref
      .watch(booruConfigProvider)
      .map((config) => config.id)
      .toSet();
  final state = ref.watch(followingTopicsProvider).valueOrNull;
  if (state == null) return false;
  final newSearchIds = {
    for (final search in state.topics)
      if (search.hasNewPosts) search.id,
  };
  return state.feeds.any(
    (feed) =>
        profiles.contains(feed.profileId) &&
        feed.sourceIds.any(newSearchIds.contains),
  );
});
