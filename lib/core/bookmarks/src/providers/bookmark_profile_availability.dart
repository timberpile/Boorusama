import '../../../content/groups/group_source_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../content/anonymous_source_policy.dart';
import '../../../content/anonymous_access_provider.dart';
import '../../../content/types.dart';
import '../../../posts/details/src/types/post_presentation_fallback_reason.dart';
import '../../../posts/post/types.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';
import 'bookmark_group_selectors.dart';
import 'bookmark_provider.dart';
import 'pool_bookmark_provider.dart';

/// A local presentation projection, never a request permission or storage filter.
class BookmarkProfileAvailability {
  BookmarkProfileAvailability(
    BookmarkLibraryState library,
    List<BooruConfig> profiles, {
    AnonymousSourcePolicy policy = const AnonymousSourcePolicy(),
    bool Function(ContentReference reference)? supportsGroup,
    ContentReferenceCodec references = const ContentReferenceCodec(),
  }) {
    final posts = <int>{};
    final collections = <String>{};
    final reasons = <Object, PostPresentationFallbackReason>{};
    for (final bookmark in library.items) {
      final post = bookmark.post;
      final resolution = const PostOriginResolver().resolve(
        post.origin,
        profiles,
        allowProfileHintFallback: true,
      );
      final source = policy.forNamespace(
        post.origin.booruType,
        post.origin.sourceHost,
      );
      final hasSafeMedia =
          source != null &&
          [
            post.thumbnailImageUrl,
            post.sampleImageUrl,
            post.originalImageUrl,
            post.videoUrl,
            post.videoThumbnailUrl,
          ].any((url) {
            final uri = Uri.tryParse(url);
            return uri != null && source.allowsMedia(uri);
          });
      switch (resolution) {
        case ResolvedPostOrigin():
          posts.add(bookmark.id);
        case MissingPostOrigin() when hasSafeMedia:
          posts.add(bookmark.id);
        case AmbiguousPostOrigin():
          reasons[bookmark.id] =
              PostPresentationFallbackReason.ambiguousProfile;
        case MissingPostOrigin():
          reasons[bookmark.id] = source == null
              ? PostPresentationFallbackReason.missingProfile
              : PostPresentationFallbackReason.unavailableEngine;
      }
    }
    for (final collection in library.pools) {
      final profile = resolvePoolBookmarkProfile(collection, profiles);
      final resolution = const PostOriginResolver().resolve(
        collection.origin,
        profiles,
        allowProfileHintFallback: false,
      );
      final key = collection.bookmarkId ?? ('pool', collection.localId);
      if (resolution is AmbiguousPostOrigin) {
        reasons[key] = PostPresentationFallbackReason.ambiguousProfile;
        continue;
      }
      ContentReference? reference;
      final site =
          collection.sourceSite ??
          (profile == null ? null : Uri.tryParse(profile.url));
      if (site != null &&
          collection.sourceTypeId == collection.origin.booruType.id &&
          normalizePostSourceHost(site.toString()) ==
              collection.origin.sourceHost) {
        try {
          reference = references.parse(
            engine: collection.origin.booruType,
            site: site,
            kind: ContentKind.group,
            sourceKey:
                '${collection.isRelated ? 'related' : 'pool'}:${collection.referenceId}',
          );
        } on FormatException {
          reference = null;
        }
      }
      // A registry-free caller retains its legacy private projection. Public
      // display always requires both a proven locator and registered reader.
      final supported = supportsGroup == null
          ? profile != null
          : reference != null && supportsGroup(reference);
      final public = reference == null
          ? null
          : policy.resolve(reference.engine, reference.site);
      if (supported && (profile != null || public != null)) {
        collections.add(collection.localId);
      } else {
        reasons[key] =
            profile != null ||
                (supportsGroup == null
                    ? policy.forNamespace(
                            collection.origin.booruType,
                            collection.origin.sourceHost,
                          ) !=
                          null
                    : public != null)
            ? PostPresentationFallbackReason.unavailableEngine
            : PostPresentationFallbackReason.missingProfile;
      }
    }
    postIds = Set.unmodifiable(posts);
    collectionIds = Set.unmodifiable(collections);
    unavailableReasons = Map.unmodifiable(reasons);
    recordIds = Set.unmodifiable({
      ...postIds,
      for (final collection in library.pools)
        if (collectionIds.contains(collection.localId) &&
            collection.bookmarkId != null)
          collection.bookmarkId!,
    });
  }

  late final Set<int> postIds;
  late final Set<String> collectionIds;
  late final Set<int> recordIds;

  /// Scope summaries before availability hides saved Posts from the grid.
  BookmarkUnavailableSummary summarizeUnavailablePosts({
    required BookmarkLibraryState library,
    required BookmarkView view,
    required List<String> selectedTags,
    String? selectedBooruUrl,
    Map<int, PostPresentationFallbackReason> observedFailures = const {},
  }) {
    final ids = view.kind == BookmarkViewKind.all
        ? null
        : library.bookmarkIdsForView(view);
    final matches = matchingBookmarks(
      bookmarks: library.items.where(
        (bookmark) =>
            (!postIds.contains(bookmark.id) ||
                observedFailures.containsKey(bookmark.id)) &&
            (ids == null || ids.contains(bookmark.id)),
      ),
      selectedTags: selectedTags,
      selectedBooruUrl: selectedBooruUrl,
    );
    final seen = <int>{};
    final sites = <String, int>{};
    final reasons = <PostPresentationFallbackReason, int>{};
    for (final bookmark in matches) {
      final reason =
          unavailableReasons[bookmark.id] ?? observedFailures[bookmark.id];
      if (reason == null || !seen.add(bookmark.id)) continue;
      final host = bookmarkSourceHost(bookmark) ?? '';
      sites.update(host, (count) => count + 1, ifAbsent: () => 1);
      reasons.update(reason, (count) => count + 1, ifAbsent: () => 1);
    }
    return BookmarkUnavailableSummary(
      sites: Map.unmodifiable(sites),
      reasons: Map.unmodifiable(reasons),
    );
  }

  Map<String, int> unavailablePostsBySite({
    required BookmarkLibraryState library,
    required BookmarkView view,
    required List<String> selectedTags,
    String? selectedBooruUrl,
  }) => summarizeUnavailablePosts(
    library: library,
    view: view,
    selectedTags: selectedTags,
    selectedBooruUrl: selectedBooruUrl,
  ).sites;

  /// Keys are saved record IDs, or legacy collection keys when no ID exists.
  late final Map<Object, PostPresentationFallbackReason> unavailableReasons;

  /// Count distinct unavailable entries after view, source and tag selection.
  Map<PostPresentationFallbackReason, int> countsForEntries(
    Iterable<BookmarkGridEntry> entries,
  ) {
    final seen = <Object>{};
    final counts = <PostPresentationFallbackReason, int>{};
    for (final entry in entries) {
      final key = switch (entry) {
        BookmarkPostEntry(:final bookmark) => bookmark.id,
        BookmarkPoolEntry(:final pool) =>
          pool.bookmarkId ?? ('pool', pool.localId),
      };
      final reason = unavailableReasons[key];
      if (reason != null && seen.add(key)) {
        counts.update(reason, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return Map.unmodifiable(counts);
  }
}

class BookmarkUnavailableSummary {
  const BookmarkUnavailableSummary({
    this.sites = const {},
    this.reasons = const {},
  });
  final Map<String, int> sites;
  final Map<PostPresentationFallbackReason, int> reasons;
}

final bookmarkProfileAvailabilityProvider =
    Provider.autoDispose<BookmarkProfileAvailability?>(
      (ref) {
        final library = ref.watch(bookmarkProvider).valueOrNull;
        final profiles = ref.watch(booruConfigProvider);
        return library == null
            ? null
            : BookmarkProfileAvailability(
                library,
                profiles,
                policy: ref.watch(anonymousSourcePolicyProvider),
                references: library.pools.isEmpty
                    ? const ContentReferenceCodec()
                    : ref.watch(contentReferenceCodecProvider),
                supportsGroup: (reference) =>
                    ref
                        .watch(booruGroupCapabilityProvider(reference.engine))
                        ?.presentation
                        .supports(ContentGroupSummary(reference: reference)) ??
                    false,
              );
      },
      dependencies: [
        bookmarkProvider,
        booruConfigProvider,
        anonymousSourcePolicyProvider,
        contentReferenceCodecProvider,
        booruGroupCapabilityProvider,
      ],
    );
