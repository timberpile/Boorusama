import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boorus/pixiv/client_provider.dart';
import '../../../boorus/pixiv/posts/types.dart';
import '../../../boorus/pixiv/works/work_mapper.dart';
import '../../blacklists/providers.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../../content/content_access_provider.dart';
import '../../content/content_entry.dart';
import '../../http/client/coordination.dart';
import '../post/providers.dart';
import 'lookup_preferences.dart';
import 'src/data/post_lookup_visibility.dart';
import 'types.dart';

typedef PixivArtworkLookup = Future<PostLookupResult> Function(
  BooruConfig target,
  int artworkId,
  PostLookupCancellation cancellation,
);

final pixivArtworkLookupProvider = Provider<PixivArtworkLookup>((ref) {
  return (target, artworkId, cancellation) async {
    if (!supportsPixivArtworkTarget(target) || artworkId <= 0) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.unsupported,
      );
    }
    bool selected() =>
        !cancellation.isCancelled &&
        ref.read(booruConfigProvider).contains(target);

    if (!selected()) return const PostLookupCancelled();
    try {
      await ref.read(blacklistTagsProvider(target.filter).future);
      if (!selected()) return const PostLookupCancelled();
      final access = ref.read(contentProfileAccessProvider(target.id));
      if (access == null || access.config != target) {
        return const PostLookupUnavailable(
          PostLookupUnavailableReason.invalidTarget,
        );
      }
      final tags = ref
          .read(contentEffectiveBlacklistProvider(target.id))
          .requireValue;
      bool current() =>
          selected() &&
          identical(ref.read(contentAccessContextProvider(access.key)), access);
      final client = ref.read(pixivClientProvider(target.auth));
      final dto = await runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.userInitiated,
          canStart: current,
          canAdmit: current,
        ),
        () => client.getIllustDetail(illustId: artworkId),
      );
      if (!current()) return const PostLookupCancelled();
      if (dto != null && dto.id != artworkId) {
        return const PostLookupInvalidResponse();
      }

      final entries =
          dto != null &&
              pixivWorkIsVisible(dto) &&
              pixivWorkPassesFilters(dto, access, tags)
          ? pixivWorkListingEntries(
              PixivIllustListResult(illusts: [dto]),
              access: access,
            )
          : const <ContentEntry>[];
      final entry = entries.firstOrNull;
      if (entry != null &&
          (entry is! PostContentEntry ||
              (!entry.post.isRestricted &&
                  isExactLookupPostVisible(entry.post, target, tags)))) {
        return PixivArtworkMatch(entry: entry, access: access.key);
      }
      return PostLookupPage(
        targetOrigin: postOriginFromConfig(target),
        posts: const [],
        page: 1,
        hasMore: false,
        hasFilteredMatches: dto != null,
        matchKind: PostLookupMatchKind.pixivSource,
      );
    } catch (error) {
      return selected() ? PostLookupFailed(error) : const PostLookupCancelled();
    }
  };
});
