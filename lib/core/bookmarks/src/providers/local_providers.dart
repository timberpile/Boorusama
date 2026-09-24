// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../boorus/anime-pictures/tags/providers.dart';
import '../../../../boorus/e621/tags/providers.dart';
import '../../../../boorus/gelbooru_v2/tags/providers.dart';
import '../../../../boorus/hybooru/tags/providers.dart';
import '../../../../foundation/riverpod/riverpod.dart';
import '../../../boorus/booru/types.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../../../tags/local/providers.dart';
import '../../../tags/tag/providers.dart';
import '../../../tags/tag/types.dart';
import '../../providers.dart';

export 'bookmark_group_selectors.dart' show BookmarkSortType, filterBookmarks;

final bookmarkEditProvider = StateProvider.autoDispose<bool>((ref) => false);

final tagCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  tag,
) async {
  final tagMap = await ref.watch(tagMapProvider.future);

  return tagMap[tag] ?? 0;
});

final tagMapProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  ref.cacheFor(const Duration(seconds: 3));
  final bookmarks = (await ref.watch(bookmarkProvider.future)).items;

  return bookmarks.fold<Map<String, int>>(
    {},
    (map, bookmark) {
      for (final tag in bookmark.tags) {
        map.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
      return map;
    },
  );
});

final selectedBooruUrlProvider = StateProvider.autoDispose<String?>((ref) {
  return null;
});

final selectedBookmarkSortTypeProvider =
    StateProvider.autoDispose<BookmarkSortType>(
      (ref) => BookmarkSortType.newest,
    );

final availableBooruUrlsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final bookmarks = (await ref.watch(bookmarkProvider.future)).items;

  return bookmarks.fold(
    <String>{},
    (hosts, bookmark) {
      final uri = Uri.tryParse(bookmark.sourceUrl);
      if (uri?.host != null) hosts.add(uri!.host);
      return hosts;
    },
  ).toList();
});

final bookmarkTagGroupsProvider = FutureProvider.autoDispose
    .family<List<TagGroupItem>?, (BooruConfigAuth, Post)>((
      ref,
      params,
    ) async {
      ref.cacheFor(const Duration(seconds: 30));

      final config = params.$1;
      final post = params.$2;

      final tagExtractor = ref.watch(bookmarkTagExtractorProvider(config));

      final tags = await tagExtractor.extractTags(
        post,
      );

      return createTagGroupItems(tags);
    });

final bookmarkTagResolverProvider =
    Provider.family<TagResolver, BooruConfigAuth>((ref, config) {
      return TagResolver(
        tagCacheBuilder: () => ref.watch(tagCacheRepositoryProvider.future),
        siteHost: config.url,
        cachedTagMapper: const CachedTagMapper(),
        tagRepositoryBuilder: () => ref.read(tagRepoProvider(config)),
      );
    });

final bookmarkTagExtractorProvider =
    Provider.family<TagExtractor, BooruConfigAuth>(
      (ref, config) {
        return TagExtractorBuilder(
          siteHost: config.url,
          tagCache: ref.watch(tagCacheRepositoryProvider.future),
          sorter: TagSorter.defaults(),
          fetcher: (post, options) {
            final tagResolver = ref.read(bookmarkTagResolverProvider(config));

            final originalPostId = post.id;

            //FIXME: Need a better way to handle different booru types
            if (config.booruType == BooruType.gelbooruV2) {
              return ref.read(
                gelbooruV2TagsFromIdProvider((config, originalPostId)).future,
              );
            } else if (config.booruType == BooruType.hybooru) {
              return ref.read(
                hybooruTagsFromIdProvider((config, originalPostId)).future,
              );
            } else if (config.booruType == BooruType.zerochan) {
              return ref.read(
                hybooruTagsFromIdProvider((config, originalPostId)).future,
              );
            } else if (config.booruType == BooruType.animePictures) {
              return ref.read(
                animePicturesTagsFromIdProvider((
                  config,
                  originalPostId,
                )).future,
              );
            } else if (config.booruType == BooruType.e621) {
              final resolver = ref.read(e621TagResolverProvider(config));

              return resolver.resolveRawTags(post.tags);
            } else {
              final tags = post.tags;

              return tagResolver.resolveRawTags(tags);
            }
          },
        );
      },
    );
