// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'search_request.dart';
import 'types.dart';

final philomenaPostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>((ref, config) {
      final client = ref.watch(philomenaClientProvider(config.auth));
      final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));
      return PostRepositoryBuilder(
        tagComposer: tagComposer,
        getSettings: () async =>
            ref.read(listingSettingsForAuthProvider(config.auth)),
        fetchSingle: (id, {options}) async {
          final numericId = id as NumericPostId?;
          if (numericId == null) return Future.value();
          final post = await client.getImage(numericId.value);
          return post != null ? postDtoToPost(post, null) : null;
        },
        fetch: (tags, page, {limit, options}) async {
          final request = PhilomenaSearchRequest.fromTags(tags);
          final posts = await client.getImages(
            nativeQuery: request.query.isEmpty ? '*' : request.query,
            sortField: request.sortField,
            sortDirection: request.sortDirection,
            page: page,
            perPage: limit,
          );
          return posts.images
              .map(
                (e) => postDtoToPost(
                  e,
                  PostMetadata(
                    page: page,
                    search: tags.join(' '),
                    limit: limit,
                  ),
                ),
              )
              .toList()
              .toResult(total: posts.count);
        },
      );
    });

final philomenaMediaUrlResolverProvider =
    Provider.family<MediaUrlResolver, BooruConfigAuth>(
      (ref, config) => PhilomenaMediaUrlResolver(
        postQuality: ref.watch(postQualityProvider(config)),
      ),
    );

final philomenaUploaderQueryProvider = Provider.family<UploaderQuery?, Post>((
  ref,
  post,
) {
  return switch (post.uploaderName) {
    final uploader? => UploaderColonUploaderQuery(uploader),
    _ => null,
  };
});
