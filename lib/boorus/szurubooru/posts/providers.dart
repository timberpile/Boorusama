// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/favorites/providers.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import '../post_votes/providers.dart';
import '../tags/providers.dart';
import 'parser.dart';

final szurubooruPostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(szurubooruClientProvider(config.auth));
        final tagComposer = ref.watch(
          szurubooruTagQueryComposerProvider(config),
        );

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          fetchSingle: (id, {options}) async {
            final numericId = id as NumericPostId?;

            if (numericId == null) return Future.value();

            final post = await client.getPost(numericId.value);

            if (post == null) return null;

            final categories = await ref.read(
              szurubooruTagCategoriesProvider(config.auth).future,
            );

            return postDtoToPost(post, null, categories);
          },
          fetch: (tags, page, {limit, options}) async {
            // Match the client's offset stride explicitly, including its default.
            final pageLimit = limit ?? 100;
            final posts = await client.getPosts(
              tags: tags,
              page: page,
              limit: pageLimit,
            );

            final categories = await ref.read(
              szurubooruTagCategoriesProvider(config.auth).future,
            );

            final data = posts.posts
                .map(
                  (e) => postDtoToPost(
                    e,
                    PostMetadata(
                      page: page,
                      search: tags.join(' '),
                      limit: pageLimit,
                    ),
                    categories,
                  ),
                )
                .toList();

            if (options?.cascadeRequest ?? true) {
              ref.read(favoritesProvider(config.auth).notifier).preload(data);
              unawaited(
                ref
                    .read(szurubooruPostVotesProvider(config.auth).notifier)
                    .getVotes(data),
              );
            }

            final total = posts.total;
            return data.toResult(
              total: total,
              hasMore: total != null && total >= 0 && pageLimit > 0
                  ? page * pageLimit < total
                  : null,
            );
          },
          getSettings: () async =>
              ref.read(listingSettingsForAuthProvider(config.auth)),
        );
      },
    );

final szurubooruUploaderQueryProvider = Provider.family<UploaderQuery?, Post>((
  ref,
  post,
) {
  return switch (post.uploaderName) {
    final uploader? => UploaderColonUploaderQuery(uploader),
    _ => null,
  };
});
