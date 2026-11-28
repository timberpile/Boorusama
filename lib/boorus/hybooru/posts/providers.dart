// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'parser.dart';

final hybooruPostRepoProvider =
    Provider.family<PostRepository, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(hybooruClientProvider(config.auth));
        final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          fetchSingle: (id, {options}) async {
            final numericId = id as NumericPostId?;

            if (numericId == null) return Future.value();

            final post = await client.getPost(id: numericId.value);
            return post != null
                ? postDtoToPost(post, null, config.auth.url)
                : null;
          },
          fetch: (tags, page, {limit, options}) async {
            final query = tags.isNotEmpty ? tags.join(' ') : null;
            final posts = await client.getPosts(
              query: query,
              page: page - 1,
              pageSize: limit,
            );
            final pageSize = switch (posts.pageSize) {
              final int size when size > 0 => size,
              _ => null,
            };
            return posts.posts
                .map(
                  (e) => postSummaryToPost(
                    e,
                    PostMetadata(
                      page: page,
                      search: tags.join(' '),
                      limit: pageSize ?? limit,
                    ),
                    config.auth.url,
                  ),
                )
                .toList()
                .toResult(
                  total: posts.total,
                  pageSize: pageSize,
                  hasMore: switch ((posts.total, pageSize)) {
                    (final int total, final int stride) =>
                      page * stride < total,
                    (_, final int stride) => posts.posts.length >= stride,
                    _ => null,
                  },
                );
          },
          getSettings: () async =>
              ref.read(listingSettingsForAuthProvider(config.auth)),
        );
      },
    );
