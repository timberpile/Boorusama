// Package imports:
import 'package:booru_clients/anime_pictures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/providers.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/options/search_id_parameters.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../../../foundation/riverpod/riverpod.dart';
import '../client_provider.dart';
import 'parser.dart';
import '../downloads/url_provider.dart';

final animePicturesPostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>((ref, config) {
      final client = ref.watch(animePicturesClientProvider(config.auth));
      final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));
      return PostRepositoryBuilder(
        tagComposer: tagComposer,
        fetchSingle: (id, {options}) {
          final numericId = id as NumericPostId?;
          if (numericId == null) return Future.value();
          return ref.read(
            animePicturesResolvedPostProvider((config.auth, numericId.value))
                .future,
          );
        },
        fetch: (tags, page, {limit, options}) async {
          final request = splitSearchIdParameters(tags, const {'stars_by'});
          final result = await client.getPostsWithTotal(
            tags: request.terms,
            starsBy: request.ids['stars_by'],
            page: page,
            limit: limit,
          );
          return result.posts
              .map(
                (e) => dtoToAnimePicturesPost(
                  e,
                  metadata: PostMetadata(
                    page: page,
                    search: tags.join(' '),
                    limit: limit,
                  ),
                ),
              )
              .toList()
              .toResult(total: result.postsCount, maxPage: result.appMaxPage);
        },
        getSettings: () async =>
            ref.read(listingSettingsForAuthProvider(config.auth)),
      );
    });

final postDetailsProvider = FutureProvider.autoDispose
    .family<PostDetailsDto, (BooruConfigAuth, int)>((ref, params) {
      ref.cacheFor(const Duration(seconds: 30));
      final (config, id) = params;
      final client = ref.watch(animePicturesClientProvider(config));
      return client.getPostDetails(id: id);
    });

final animePicturesMediaUrlResolverProvider =
    Provider.family<MediaUrlResolver, BooruConfigAuth>(
      (ref, config) => ref.watch(defaultMediaUrlResolverProvider(config)),
    );

final animePicturesResolvedPostProvider = FutureProvider.autoDispose
    .family<Post?, (BooruConfigAuth, int)>((ref, request) async {
      ref.cacheFor(const Duration(seconds: 30));
      final (config, id) = request;
      final resolver = ref.watch(
        animePicturesDownloadFileUrlExtractorProvider(config),
      );
      final details = await ref.watch(postDetailsProvider(request).future);
      final post = details.post;
      if (post == null) return null;
      String? original;
      try {
        original = (await resolver.resolveOriginal(id, details: details))?.url;
      } catch (_) {
        // Authored metadata remains useful when Original is access restricted.
      }
      return dtoToAnimePicturesPost(
        post,
        details: details,
        originalUrl: original,
      );
    });
