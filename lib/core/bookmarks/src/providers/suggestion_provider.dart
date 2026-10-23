// Dart imports:
import 'dart:ui' show Brightness;

// Flutter imports:
import 'package:flutter/painting.dart';

// Package imports:
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../posts/post/types.dart';
import '../../../tags/categories/providers.dart';
import '../../../tags/tag/colors.dart';
import '../../../themes/colors/providers.dart';
import '../../../themes/configs/providers.dart';
import '../../../themes/configs/types.dart';
import '../data/bookmark_tag_color.dart';
import '../types/bookmark_tag_index.dart';
import '../types/bookmark_view.dart';
import 'bookmark_details_mutation_notifier.dart';
import 'bookmark_provider.dart';
import 'local_providers.dart';

final _bookmarkTagIndexBuilderProvider = Provider.autoDispose
    .family<BookmarkTagIndexBuilder, BookmarkView>((ref, view) {
      final configs = ref.watch(booruConfigProvider);
      return BookmarkTagIndexBuilder(
        siteUrl: (bookmark) => switch (const PostOriginResolver().resolve(
          bookmark.post.origin,
          configs,
        )) {
          ResolvedPostOrigin(:final config) => config.auth.url,
          _ => bookmark.sourceUrl,
        },
      );
    });

final bookmarkTagIndexProvider = FutureProvider.autoDispose
    .family<BookmarkTagIndex, BookmarkView>((ref, view) async {
      final builder = ref.watch(_bookmarkTagIndexBuilderProvider(view));
      final viewerVisible = ref.watch(
        bookmarkDetailsMutationProvider.select((state) => state.isVisible),
      );
      // The covered search bar stays mounted while viewing posts. Retain its
      // current suggestions instead of rebuilding every tag after each toggle.
      // Closing the viewer reconnects to the latest library/source/profiles.
      if (viewerVisible) {
        return ref.state.valueOrNull ?? BookmarkTagIndex(const []);
      }
      final libraryFuture = ref.watch(bookmarkProvider.future);
      final source = ref.watch(selectedBooruUrlProvider);
      var obsolete = false;
      ref.onDispose(() => obsolete = true);
      final library = await libraryFuture;
      // A superseded asynchronous load must not roll the retained builder back.
      if (obsolete) return BookmarkTagIndex(const []);
      // Autocomplete counts do not depend on the grid's date/shuffle ordering.
      final bookmarks = switch (view.kind) {
        BookmarkViewKind.all => library.items,
        BookmarkViewKind.group => [
          for (final id
              in library.groupsById[view.groupId]?.bookmarkIds ?? const <int>{})
            ?library.bookmarksById[id],
        ],
      };
      return builder.update(
        source == null
            ? bookmarks
            : bookmarks.where(
                (bookmark) => bookmark.sourceUrl.contains(source),
              ),
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
    .family<Color?, (BookmarkView, String, Brightness)>(
      (ref, request) {
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
        final engine = ref.watch(booruEngineRegistryProvider);
        final customColors = ref.watch(customColorsProvider);
        final scheme = ref.watch(colorSchemeProvider);
        final dynamicColors = ref.watch(enableDynamicColoringProvider);
        return resolveBookmarkTagColor(
          entry,
          colors: TagColors.fromBrightness(brightness),
          colorsForType: (type) => customColors != null
              ? getTagColorsFromColorSettings(customColors)
              : engine
                    .getRepository(type)
                    ?.tagColorGenerator()
                    .generateColors(
                      TagColorsOptions(brightness: brightness),
                    ),
          transformColor: (color) =>
              dynamicColors ? color.harmonizeWith(scheme.primary) : color,
          categoryLookup: (site, name) async {
            final store = await storeFuture;
            return store?.getTagCategory(site, name);
          },
          colorGenerator: (type) =>
              engine.getRepository(type)?.tagColorGenerator(),
        );
      },
      dependencies: [
        customColorsProvider,
        colorSchemeProvider,
        enableDynamicColoringProvider,
      ],
    );
