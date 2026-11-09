import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/blacklists/providers.dart';
import '../../../core/content/capabilities.dart';
import '../../../core/content/types.dart';
import '../../../core/content/groups/group_visibility.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/details/src/widgets/media_group_viewer.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../foundation/loggers.dart';
import '../client_provider.dart';
import '../tags/providers.dart';
import 'source.dart';
import 'mapper.dart';

BooruGroupCapability createNhentaiGroupCapability(Ref ref) =>
    BooruGroupCapability(
      engine: BooruType.nhentai,
      keyCodec: const BooruContentKeyCodec(BooruType.nhentai),
      createSource: (access) {
        final config = access.config!;
        final client = ref.read(nhentaiClientProvider(config.auth));
        return NhentaiGallerySource(
          access: access,
          mediaPolicy: () =>
              ref.read(nhentaiMediaPolicyProvider(config.auth).future),
          fetchGallery: (id) async {
            final result = await client.getGallery(id);
            final blacklist = await ref.read(
              blacklistTagsProvider(config.filter).future,
            );
            if (!groupAllowsRating(config, Rating.unknown) ||
                !groupTagsPassBlacklist(
                  nhentaiGroupTags(result),
                  blacklist,
                  rating: Rating.unknown,
                  sourceId: id,
                  sourceUrl: 'https://nhentai.net/g/$id/',
                )) {
              throw StateError('Gallery hidden by current policy');
            }
            // Cached tag observations never delay Page display or cause another
            // network lookup when the details envelope already names the tags.
            unawaited(
              ref
                  .read(nhentaiTagCacheProvider(config.auth))
                  .remember(result.tags)
                  .catchError((Object error, StackTrace stack) {
                    ref
                        .read(loggerProvider)
                        .handledError(
                          'NhentaiTags',
                          'persist_observed_tags',
                          error: error,
                          stackTrace: stack,
                        );
                  }),
            );
            return result;
          },
        );
      },
      presentation: const NhentaiGroupPresentation(),
    );

class NhentaiGroupPresentation implements BooruGroupPresentation {
  const NhentaiGroupPresentation();
  @override
  bool supports(ContentGroupSummary summary) =>
      summary.reference.engine == BooruType.nhentai &&
      summary.reference.sourceKey.startsWith('gallery:');
  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.mediaPager;
  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.artist_page.posts;
  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      GroupSummaryCard(summary: summary, kind: PoolGridItemKind.collection);
  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) =>
      MediaGroupViewer(details: details);
}
