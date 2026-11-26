import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/blacklists/providers.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/rating/types.dart';
import '../tags/providers.dart';
import 'mapper.dart';
import 'source.dart';

final nhentaiGalleryListingProvider = Provider.autoDispose
    .family<NhentaiGalleryListing?, ContentAccessKey>(
      (ref, key) {
        final access = ref.watch(contentAccessContextProvider(key));
        final source = ref
            .watch(contentGroupSourceStateProvider(key))
            .valueOrNull;
        if (access == null || source is! NhentaiGallerySource) return null;
        final blacklist = switch (key.profileId) {
          final profile? =>
            ref.watch(contentEffectiveBlacklistProvider(profile)).requireValue,
          null => {
            for (final tag
                in ref.watch(globalBlacklistedTagsProvider).requireValue)
              if (tag.isActive) tag.name,
          },
        };
        return NhentaiGalleryListing(
          source: source,
          blacklist: blacklist,
          cache: ref.watch(nhentaiTagCacheProvider(access.config!.auth)),
          current: () => ref.read(contentAccessContextProvider(key)) != null,
        );
      },
      dependencies: [
        contentAccessContextProvider,
        contentGroupSourceStateProvider,
        contentEffectiveBlacklistProvider,
      ],
    );

final class NhentaiGalleryListing {
  const NhentaiGalleryListing({
    required this.source,
    required this.blacklist,
    required this.cache,
    required this.current,
  });

  final NhentaiGallerySource source;
  final Set<String> blacklist;
  final NhentaiTagCache cache;
  final bool Function() current;

  Future<List<ContentGroupSummary>> project(
    Iterable<NhentaiGallerySummary> entries, {
    required CancelToken? cancelToken,
    bool Function()? canAdmit,
  }) async {
    final access = source.access;
    if (!groupAllowsRating(access.config!, Rating.unknown)) return const [];
    final ids = <int>{};
    final candidates = entries
        .where(
          (item) => item.blacklisted != true && ids.add(item.id),
        )
        .toList();
    if (candidates.isEmpty) return const [];
    final policy = await source.mediaPolicy();
    final tagIds = candidates.expand((item) => item.tagIds);
    final tags = blacklist.isEmpty
        ? const <int, NhentaiTag>{}
        : await cache.resolveVisible(tagIds, cancelToken: cancelToken);
    if ((cancelToken?.isCancelled ?? false) ||
        !(canAdmit?.call() ?? true) ||
        !current()) {
      throw StateError('Gallery listing access changed');
    }
    final result =
        [
          for (final candidate in candidates)
            nhentaiGallerySummary(
              candidate,
              access,
              policy,
              resolvedTags: tags,
            ),
        ]..removeWhere(
          (summary) => !groupTagsPassBlacklist(
            summary.previewTags,
            blacklist,
            rating: Rating.unknown,
            sourceId: nhentaiIdFromReference(summary.reference),
            sourceUrl:
                'https://nhentai.net/g/${nhentaiIdFromReference(summary.reference)}/',
          ),
        );
    result.forEach(source.seedSummary);
    return result;
  }
}
