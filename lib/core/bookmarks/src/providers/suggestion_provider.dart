// Dart imports:
import 'dart:ui' show Brightness;

// Flutter imports:
import 'package:flutter/painting.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/post/types.dart';
import '../../../tags/categories/providers.dart';
import '../../../tags/tag/colors.dart';
import '../data/bookmark_tag_color.dart';
import '../types/bookmark_tag_index.dart';
import '../types/bookmark_view.dart';
import 'bookmark_group_selectors.dart';
import 'bookmark_provider.dart';
import 'local_providers.dart';

final bookmarkTagIndexProvider = FutureProvider.autoDispose
    .family<BookmarkTagIndex, BookmarkView>((ref, view) async {
      final libraryFuture = ref.watch(bookmarkProvider.future);
      final source = ref.watch(selectedBooruUrlProvider);
      final configs = ref.watch(booruConfigProvider);
      final library = await libraryFuture;
      final bookmarks = selectBookmarks(
        state: library,
        view: view,
        selectedTags: const [],
        selectedBooruUrl: source,
        sortType: BookmarkSortType.newest,
      );
      return BookmarkTagIndex.fromBookmarks(
        bookmarks,
        siteUrl: (bookmark) => switch (const PostOriginResolver().resolve(
          bookmark.post.origin,
          configs,
        )) {
          ResolvedPostOrigin(:final config) => config.auth.url,
          _ => bookmark.sourceUrl,
        },
      );
    });

// The draft and selected query are part of the key. A previous asynchronous
// index build cannot publish suggestions into a different search or page.
final bookmarkTagSuggestionsProvider = Provider.autoDispose
    .family<AsyncValue<List<BookmarkTagEntry>>, (BookmarkView, String, String)>(
      (ref, request) {
        final (view, draft, selectedQuery) = request;
        return ref
            .watch(bookmarkTagIndexProvider(view))
            .whenData(
              (index) => index.suggestions(
                draft,
                selectedTags: selectedQuery.split(RegExp(r'\s+')).toSet(),
              ),
            );
      },
    );

final bookmarkTagColorProvider = FutureProvider.autoDispose
    .family<Color?, (BookmarkView, String, Brightness)>((ref, request) {
      final (view, tag, brightness) = request;
      final index = ref.watch(bookmarkTagIndexProvider(view));
      final entry = index.valueOrNull?.byName[tag];
      if (entry == null) return null;
      final needsCache = entry.sources.values.any(
        (categories) => categories.isEmpty,
      );
      final storeFuture = needsCache
          ? ref.watch(booruTagTypeStoreProvider.future)
          : null;
      final engine = needsCache ? ref.watch(booruEngineRegistryProvider) : null;
      return resolveBookmarkTagColor(
        entry,
        colors: TagColors.fromBrightness(brightness),
        categoryLookup: (site, name) async {
          final store = await storeFuture;
          return store?.getTagCategory(site, name);
        },
        colorGenerator: (type) =>
            engine?.getRepository(type)?.tagColorGenerator(),
      );
    });
