import 'bookmark_read_access.dart';
import '../../../boorus/booru/types.dart';
import '../../../boorus/engine/providers.dart';
import '../../../content/groups/group_source_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../content/anonymous_source_policy.dart';
import '../../../content/anonymous_access_provider.dart';
import '../../../content/types.dart';
import '../../../posts/details/src/types/post_presentation_fallback_reason.dart';
import '../../../posts/post/types.dart';
import '../types/bookmark_grid_entry.dart';
import '../types/content_group_bookmark.dart';
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
    bool Function(BooruType engine)? supportsPost,
    ContentReferenceCodec references = const ContentReferenceCodec(),
  }) {
    final posts = <int>{};
    final collections = <String>{};
    final reasons = <Object, PostPresentationFallbackReason>{};
    for (final bookmark in library.items) {
      final post = bookmark.post;
      final profile = selectBookmarkReadProfile(
        BookmarkReaderRequest(post.origin),
        profiles,
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
      if (profile != null ||
          (hasSafeMedia &&
              (supportsPost?.call(post.origin.booruType) ?? true))) {
        posts.add(bookmark.id);
      } else {
        reasons[bookmark.id] = source == null
            ? PostPresentationFallbackReason.missingProfile
            : PostPresentationFallbackReason.unavailableEngine;
      }
    }

    for (final collection in library.pools) {
      final profile = resolvePoolBookmarkProfile(collection, profiles);
      final key = collection.bookmarkId ?? ('pool', collection.localId);
      ContentReference? reference;
      final site =
          collection.sourceSite ??
          (profile == null
              ? policy
                    .forNamespace(
                      collection.origin.booruType,
                      collection.origin.sourceHost,
                    )
                    ?.site
              : Uri.tryParse(profile.url));
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
    final native = <int>{};
    for (final record in library.records.whereType<ContentGroupBookmark>()) {
      if (record.reference.sourceKey.startsWith('pool:') ||
          record.reference.sourceKey.startsWith('related:')) {
        continue;
      }
      final profile = selectBookmarkReadProfile(
        BookmarkReaderRequest.reference(record.reference),
        profiles,
      );
      final public = policy.resolve(
        record.reference.engine,
        record.reference.site,
      );
      final supported =
          supportsGroup?.call(record.reference) ?? profile != null;
      if (supported && (profile != null || public != null)) {
        native.add(record.id);
      } else {
        reasons[record.id] = profile != null || public != null
            ? PostPresentationFallbackReason.unavailableEngine
            : PostPresentationFallbackReason.missingProfile;
      }
    }
    nativeGroupIds = Set.unmodifiable(native);
    postIds = Set.unmodifiable(posts);
    collectionIds = Set.unmodifiable(collections);
    unavailableReasons = Map.unmodifiable(reasons);
    recordIds = Set.unmodifiable({
      ...postIds,
      ...nativeGroupIds,
      for (final collection in library.pools)
        if (collectionIds.contains(collection.localId) &&
            collection.bookmarkId != null)
          collection.bookmarkId!,
    });
  }

  late final Set<int> postIds;
  late final Set<int> nativeGroupIds;
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
    final ids = library.bookmarkIdsForView(view);
    final matches = matchingBookmarks(
      bookmarks: library.items.where(
        (bookmark) =>
            (!postIds.contains(bookmark.id) ||
                observedFailures.containsKey(bookmark.id)) &&
            ids.contains(bookmark.id),
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
    for (final bookmark in selectNativeGroupBookmarks(
      state: library,
      view: view,
      selectedTags: selectedTags,
      selectedBooruUrl: selectedBooruUrl,
    )) {
      final reason =
          unavailableReasons[bookmark.id] ?? observedFailures[bookmark.id];
      if (reason == null || !seen.add(bookmark.id)) continue;
      sites.update(
        bookmark.reference.siteNamespace,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
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
        BookmarkNativeGroupEntry(:final bookmark) => bookmark.id,
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
        final profiles = ref.watch(bookmarkReadProfilesProvider);
        return library == null
            ? null
            : BookmarkProfileAvailability(
                library,
                profiles,
                policy: ref.watch(anonymousSourcePolicyProvider),
                supportsPost: (engine) =>
                    ref.watch(booruPostCapabilityProvider(engine)) != null,
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
        bookmarkReadProfilesProvider,
        anonymousSourcePolicyProvider,
        contentReferenceCodecProvider,
        booruGroupCapabilityProvider,
        booruPostCapabilityProvider,
      ],
    );
