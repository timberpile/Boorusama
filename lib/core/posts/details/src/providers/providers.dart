// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../foundation/riverpod/riverpod.dart';
import '../../../../blacklists/providers.dart';
import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../settings/providers.dart';
import '../../../post/providers.dart';
import '../../../post/types.dart';
import '../types/media_url_resolver.dart';
import '../types/post_filter_query.dart';

final singlePostDetailsProvider = FutureProvider.autoDispose
    .family<Post?, (PostId, BooruConfig)>((ref, params) async {
      final (id, config) = params;

      final postRepo = OriginAwarePostRepository.fromConfig(
        delegate: ref.watch(postRepoProvider(config.search)),
        config: config,
      );

      final result = await postRepo.getPost(id).run();

      return result.getOrElse((_) => null);
    });

final detailsPostsProvider = FutureProvider.autoDispose
    .family<
      List<Post>,
      (BooruConfigFilter, BooruConfig, String?, PostFilterQuery)
    >((ref, params) async {
      ref.cacheFor(const Duration(seconds: 30));

      final (filter, config, tag, query) = params;

      final posts = await ref
          .watch(originAwarePostRepoProvider(config))
          .getPostsFromTagWithBlacklist(
            tag: tag,
            blacklist: ref.watch(blacklistTagsProvider(filter).future),
            options: PostFetchOptions.raw,
            softLimit: null,
          );

      return posts.where(query.shouldInclude).toList();
    });

final mediaUrlResolverProvider =
    Provider.family<MediaUrlResolver, BooruConfigAuth>(
      (ref, config) {
        final fallbackMediaUrlResolver = ref.watch(
          defaultMediaUrlResolverProvider(config),
        );

        final mediaUrlResolver =
            ref.watch(booruRepoProvider(config))?.mediaUrlResolver(config) ??
            fallbackMediaUrlResolver;

        return mediaUrlResolver;
      },
    );

final defaultMediaUrlResolverProvider =
    Provider.family<MediaUrlResolver, BooruConfigAuth>(
      (ref, config) => DefaultMediaUrlResolver(
        imageQuality: ref.watch(
          settingsProvider.select((value) => value.listing.imageQuality),
        ),
      ),
    );

final sampleMediaUrlResolverProvider =
    Provider.family<MediaUrlResolver, BooruConfigAuth>(
      (ref, config) => const SampleMediaUrlResolver(),
    );
