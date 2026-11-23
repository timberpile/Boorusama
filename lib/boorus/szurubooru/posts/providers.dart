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
import '../configs/providers.dart';
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
        final preparedFavorites = Expando<(FavoriteRead, bool)>();

        FavoritesNotifier? favoriteObserver() =>
            ref.read(szurubooruLoginDetailsProvider(config.auth)).hasLogin()
            ? ref.read(favoritesProvider(config.auth).notifier)
            : null;

        return PostRepositoryBuilder(
          onConsumePreparedPosts: (posts) async {
            final observations = <FavoriteRead, Map<int, bool>>{};
            for (final post in posts) {
              if (preparedFavorites[post] case (final read, final status)) {
                observations.putIfAbsent(read, () => {})[post.id] = status;
                preparedFavorites[post] = null;
              }
            }
            if (observations.isNotEmpty) {
              final observer = favoriteObserver();
              for (final MapEntry(key: read, value: statuses)
                  in observations.entries) {
                observer?.observeFavorites(statuses, read);
              }
            }
            await ref
                .read(szurubooruPostVotesProvider(config.auth).notifier)
                .getVotes(posts);
          },
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
            final cascade = options?.cascadeRequest ?? true;
            final prepare = options?.prepareGroupRows ?? false;
            final favorites = cascade || prepare ? favoriteObserver() : null;
            final read = favorites?.beginRead();
            // Match the client's offset stride explicitly, including its default.
            final pageLimit = limit ?? 100;
            final posts = await client.getPosts(
              tags: tags,
              page: page,
              limit: pageLimit,
            );

            final categories = prepare
                ? await readSzurubooruCategories(ref, config.auth)
                : await ref.read(
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

            if (read != null) {
              final statuses = {
                for (final post in posts.posts) ?post.id: ?post.ownFavorite,
              };
              if (prepare) {
                // Keep the original read revision while these rows await
                // foreground consumption. Stored snapshots have no entry here.
                for (final post in data) {
                  if (statuses[post.id] case final status?) {
                    preparedFavorites[post] = (read, status);
                  }
                }
              } else {
                favorites!.observeFavorites(statuses, read);
              }
            }
            if (cascade) {
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
