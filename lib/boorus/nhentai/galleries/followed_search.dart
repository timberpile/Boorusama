import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/groups/owned_read_cache.dart';
import '../../../core/content/types.dart';
import '../../../core/developer_options/providers.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import '../../../core/search/following_topics/src/refresh/gallery_topic_refresh_source.dart';
import '../client_provider.dart';
import 'listing.dart';

/// The latest search envelope can serve both checking and visible cover lookup.
/// The cover projection always runs under the current visibility policy.
final nhentaiFollowedSearchProvider =
    Provider.family<
      OwnedReadCache<String, NhentaiResultPage<NhentaiGallerySummary>>,
      (String, BooruConfigAuth)
    >((ref, owner) {
      ref.watch(nhentaiClientProvider(owner.$2));
      final cache =
          OwnedReadCache<String, NhentaiResultPage<NhentaiGallerySummary>>();
      ref.onDispose(cache.dispose);
      return cache;
    });

typedef NhentaiTopicCoversKey = (
  ContentAccessKey access,
  String query,
  DateTime? checkedAt,
);

final nhentaiTopicCoverAccessProvider = Provider.autoDispose
    .family<ContentAccessKey?, BooruConfig>(
      (ref, config) {
        final anonymous = config.anonymousReadScope;
        final access = anonymous == null
            ? ref.watch(contentProfileAccessProvider(config.id))
            : ref.watch(contentAccessContextProvider(anonymous.key));
        return access?.config?.auth == config.auth ? access?.key : null;
      },
      dependencies: [
        contentProfileAccessProvider,
        contentAccessContextProvider,
      ],
    );

final nhentaiTopicCoversProvider = FutureProvider.autoDispose
    .family<List<String>, NhentaiTopicCoversKey>(
      (ref, key) {
        final (accessKey, rawQuery, _) = key;
        if (!ref.watch(automaticMediaLoadingEnabledProvider)) return const [];
        final listing = ref.watch(nhentaiGalleryListingProvider(accessKey));
        if (listing == null) return const [];
        final access = listing.source.access;
        final config = access.config!;
        final query = ref
            .watch(defaultTagQueryComposerProvider(config.search))
            .compose([rawQuery])
            .join(' ');
        final client = ref.watch(nhentaiClientProvider(config.auth));
        final pages = ref.watch(
          nhentaiFollowedSearchProvider((config.id, config.auth)),
        );
        final loader = ref.watch(topicPreviewLoaderProvider);
        final token = CancelToken();
        ref.onDispose(token.cancel);
        bool current() =>
            !token.isCancelled &&
            identical(
              ref.read(contentAccessContextProvider(accessKey)),
              access,
            );

        return loader.load(
          canStart: current,
          fetch: () => runWithApiRequestContext(
            ApiRequestContext(
              requestClass: ApiRequestClass.preload,
              replaySafety: ApiReplaySafety.safeRead,
              admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
              allowCooldownRetry: false,
              cancelToken: token,
              canStart: current,
              canAdmit: current,
            ),
            () async {
              final page = await pages.load(
                query,
                () => client.getGalleries(
                  query: query,
                  cancelToken: ApiRequestContext.current().cancelToken,
                ),
              );
              final summaries = await listing.project(
                page.items.take(GalleryTopicRefreshPage.maxResults),
                cancelToken: token,
                canAdmit: current,
              );
              return [
                for (final summary in summaries)
                  if (summary.cover?.thumbnail case final uri?) uri.toString(),
              ];
            },
          ),
        );
      },
      dependencies: [
        contentAccessContextProvider,
        nhentaiGalleryListingProvider,
      ],
    );
