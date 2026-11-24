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
import '../types/content_group_bookmark.dart';
import '../types/bookmark_view.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/bookmark_record_fields.dart';

export 'bookmark_group_selectors.dart' show BookmarkSortType, filterBookmarks;

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
  final (bookmarks, pools, records) = await ref.watch(
    bookmarkProvider.selectAsync(
      (state) => (state.localItems, state.localPools, state.localRecords),
    ),
  );

  final result = bookmarks.fold<Map<String, int>>(
    {},
    (map, bookmark) {
      for (final tag in bookmark.tags) {
        map.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
      return map;
    },
  );
  for (final pool in pools) {
    for (final tag in pool.tags) {
      result.update(tag, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  for (final record in records.whereType<ContentGroupBookmark>()) {
    if (!isNativeGroupBookmark(record)) continue;
    for (final tag in nativeGroupBookmarkTags(record)) {
      result.update(tag, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return result;
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
  final (bookmarks, pools, records) = await ref.watch(
    bookmarkProvider.selectAsync(
      (state) => (state.localItems, state.localPools, state.localRecords),
    ),
  );

  final hosts = <String>{
    for (final bookmark in bookmarks) ?bookmarkSourceHost(bookmark),
  };
  hosts.addAll(
    pools
        .map((p) => Uri.tryParse('https://${p.origin.sourceHost}')?.host)
        .nonNulls
        .where((host) => host.isNotEmpty)
        .map((host) => host.toLowerCase()),
  );
  hosts.addAll(
    records
        .whereType<ContentGroupBookmark>()
        .where(isNativeGroupBookmark)
        .map((record) => record.reference.siteNamespace),
  );
  return hosts.toList();
});

/// Structural source scope, independent of query, Seen, sorting or readers.
final availableBookmarkViewSourcesProvider = FutureProvider.autoDispose
    .family<List<String>, BookmarkView>((ref, view) async {
      if (view.kind == BookmarkViewKind.all) {
        return ref.watch(availableBooruUrlsProvider.future);
      }
      final library = await ref.watch(bookmarkProvider.future);
      final ids = library.bookmarkIdsForView(view);
      final hosts = <String>{
        for (final id in ids)
          if (library.bookmarksById[id] case final bookmark?)
            ?bookmarkSourceHost(bookmark),
        for (final pool in selectPoolBookmarks(
          state: library,
          view: view,
          selectedTags: const [],
        ))
          if (Uri.tryParse('https://${pool.origin.sourceHost}')?.host
              case final host? when host.isNotEmpty)
            host.toLowerCase(),
        for (final record in selectNativeGroupBookmarks(
          state: library,
          view: view,
          selectedTags: const [],
        ))
          record.reference.siteNamespace,
      };
      return hosts.toList();
    });

/// Pending data cannot invalidate a carried-over choice. All consumers use the
/// same effective value while the mounted active picker clears obsolete state.
final effectiveBookmarkSourceProvider = Provider.autoDispose
    .family<String?, BookmarkView>((ref, view) {
      final selected = ref.watch(selectedBooruUrlProvider);
      final sources = ref.watch(availableBookmarkViewSourcesProvider(view));
      if (selected == null ||
          sources.isLoading ||
          sources.hasError ||
          !sources.hasValue) {
        return selected;
      }
      return sources.requireValue.any(
            (source) => bookmarkSourceMatchesHost(source, selected),
          )
          ? selected
          : null;
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
