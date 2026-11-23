import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backups/sources/search_backup_profile.dart';
import '../../../../boorus/booru/types.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../content/anonymous_access_provider.dart';
import 'following_topics_notifier.dart';
import '../types/following_mirror_state.dart';
import '../types/following_topic_source.dart';

bool sameFollowingReader(BooruConfig? current, BooruConfig expected) =>
    current?.id == expected.id &&
    current?.auth == expected.auth &&
    (expected.anonymousReadScope?.isCurrent ?? true);

final _enginesByName = {
  for (final config in BooruYamlConfigs.byId.values)
    config.type.name: config.type,
};

/// Received definitions carry source identity, never authority to use an account.
/// Public fallback uses the same revocable, credential-free policy as Bookmarks.
final followingTopicConfigProvider = Provider.autoDispose
    .family<BooruConfig?, String>((ref, id) {
      final state = ref.watch(followingTopicsProvider).valueOrNull;
      final topic = state?.topics.where((topic) => topic.id == id).firstOrNull;
      if (topic == null) return null;
      return ref.watch(
        followingSourceConfigProvider((
          profileId: topic.profileId,
          owner: state!.mirrors.owners[id],
          localSource: topic.localSource,
        )),
      );
    });

// Refresh operations consume the captured source directly, avoiding a provider
// dependency back into their own FollowingTopicsNotifier.
final followingSourceConfigProvider = Provider.autoDispose
    .family<
      BooruConfig?,
      ({
        String profileId,
        FollowingMirrorOwner? owner,
        FollowingTopicSource? localSource,
      })
    >((
      ref,
      request,
    ) {
      final profiles = ref.watch(booruConfigProvider);
      final owner = request.owner;
      if (owner == null && request.localSource == null) {
        return profiles
            .where((profile) => profile.id == request.profileId)
            .firstOrNull;
      }
      final localSource = request.localSource;
      if (owner == null && localSource != null) {
        final compatible = profiles
            .where(
              (profile) => localSource.matches(
                profile.auth.booruType.name,
                normalizeBackupProfileUrl(profile.url),
              ),
            )
            .toList();
        // A portable import is not owned by its synthetic storage namespace or
        // foreign profile UUID. Resolve only an unambiguous current actor.
        // Existing local copies keep their chosen binding and must not silently
        // switch to another account on the same site.
        final bound = localSource.isImported
            ? (compatible.length == 1 ? compatible.single : null)
            : compatible
                  .where((profile) => profile.id == request.profileId)
                  .firstOrNull;
        if (bound != null) return bound;
        final public = localSource.anonymous(
          ref.watch(anonymousSourcePolicyProvider),
        );
        return public == null
            ? null
            : ref.watch(anonymousContentAccessProvider(public))?.config;
      }
      final source = owner?.profile;
      if (source == null) return null;
      final engine = _enginesByName[source['booruType']];
      final site = Uri.tryParse(source['url'] as String? ?? '');
      if (engine == null || site == null) return null;
      final compatible = profiles
          .where(
            (profile) =>
                profile.auth.booruType == engine &&
                normalizeBackupProfileUrl(profile.url) ==
                    normalizeBackupProfileUrl(site.toString()),
          )
          .toList();
      if (compatible.length == 1) return compatible.single;
      final public = ref
          .watch(anonymousSourcePolicyProvider)
          .resolve(engine, site);
      if (public == null) return null;
      return ref.watch(anonymousContentAccessProvider(public))?.config;
    });
