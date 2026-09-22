# Unified Post Model and Mixed-Booru Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give search, server favorites, bookmarks, and Following Feeds one concrete runtime `Post`, one shared card renderer, and one viewer that dynamically applies the current post's booru-specific data and behavior.

**Architecture:** Introduce versioned, JSON-safe snapshots and typed engine payloads behind registry-owned codec and presentation capabilities. Migrate current engine models through a temporary `UnifiedPost` bridge so every commit stays runnable, then rename that bridge to the sole concrete `Post` and remove the old hierarchy. Resolve each page's profile locally from `PostOrigin`; missing or ambiguous capabilities render cached media through a generic warning presentation without mutating the globally selected profile.

**Tech Stack:** Flutter, Dart, Riverpod, Equatable, Hive CE, Slang i18n, widget/unit tests, Maestro on Android.

**Spec:** `docs/superpowers/specs/2026-09-22-unified-post-model-and-viewer-design.md`

## Global Constraints

- Work only on `feature/bookmark-post-behavior-parity` in `.worktrees/bookmark-post-behavior-parity`.
- Use `fvm` for every Dart and Flutter command and run `fvm dart format` after each edited Dart batch.
- Use test-first changes: add a focused failing behavior test, run it to observe the expected failure, implement the minimum production behavior, then rerun it.
- Do not use the abandoned feed-rendering branch as code input. Re-verify any useful observation against this worktree.
- Keep `PostOrigin` credential-free and never choose an arbitrary profile when matching is ambiguous.
- Preserve nullability from external APIs. A missing value remains absent rather than becoming `0`, `false`, or `unknown`.
- Keep feed ownership, refresh, checkpoint, history, retention, and `NEW` semantics unchanged.
- Keep bookmark identity, group membership, removal, conflict, scoped export, and rollback semantics unchanged.
- Preserve existing local Hive bookmarks. Keep version-1 backup import localized; new exports use version 2 only.
- Do not add feed support or new server actions to an engine.
- The delivered tree must not retain `UnifiedPost`, `BookmarkPost`, `CachedFeedPost`, an engine-specific `Post` subclass, or generic `InheritedPost<T>`/`PostDetails<T>`.

## Stable Interfaces Used Across Tasks

The temporary `UnifiedPost` name is used only while the old abstract `Post` still exists. Task 14 renames it to `Post` without changing these fields.

```dart
abstract interface class BooruPostData {
  String get typeKey;
  int get schemaVersion;
}

final class PostOrigin extends Equatable {
  const PostOrigin({
    required this.booruType,
    required this.booruId,
    required this.sourceHost,
    this.profileIdHint,
  });

  final BooruType booruType;
  final int booruId;
  final String sourceHost;
  final int? profileIdHint;
}

final class UnifiedPost extends Equatable implements Post {
  const UnifiedPost({
    required this.origin,
    required this.core,
    required this.booruData,
  });

  final PostOrigin origin;
  final PostCoreData core;
  final BooruPostData booruData;
}

final class StoredPostSnapshot extends Equatable {
  const StoredPostSnapshot({
    required this.origin,
    required this.common,
    required this.custom,
    required this.codecVersion,
  });

  final PostOriginSnapshot origin;
  final Map<String, Object?> common;
  final Map<String, Object?> custom;
  final int codecVersion;
}

abstract interface class BooruPostDataCodec<D extends BooruPostData> {
  String get typeKey;
  int get currentVersion;
  bool supports(BooruPostData data);
  Map<String, Object?> encode(D data);
  D decode(Map<String, Object?> json, {required int version});
}
```

`StoredPostCodec` owns common/origin serialization and calls the engine codec for `custom`. Decode errors and unsupported versions return an otherwise intact post with `UnknownPostData`; version-1 bookmark adaptation returns `LegacyPostData`.

The final presentation boundary is:

```dart
abstract interface class BooruPostPresentation {
  bool supports(BooruPostData data);
  PostDetailsUIBuilder detailsBuilder(Post post);
  Widget? buildGridQuickAction(BuildContext context, Post post);
  BlockOverlayItem? buildGridBlockOverlay(BuildContext context, Post post);
}

sealed class PostOriginResolution {
  const PostOriginResolution();
}

final class ResolvedPostOrigin extends PostOriginResolution {
  const ResolvedPostOrigin(this.config);
  final BooruConfig config;
}

final class MissingPostOrigin extends PostOriginResolution {
  const MissingPostOrigin();
}

final class AmbiguousPostOrigin extends PostOriginResolution {
  const AmbiguousPostOrigin();
}
```

## Review Focus

- Every current engine field survives API-to-runtime and snapshot round trips.
- A page change swaps engine presentation and profile-scoped providers without changing global profile state.
- Unsupported, malformed, missing-profile, and ambiguous-profile cases remain navigable and use generic UI with a warning.
- Bookmark and feed migrations preserve local identifiers and surrounding feature semantics.
- The final cleanup genuinely leaves one concrete runtime post model instead of hiding the old hierarchy behind adapters.

---

## Task 1: Add the transitional unified domain and lossless common snapshot codec

**Files:**

- Create: `lib/core/posts/post/src/types/post_origin.dart`
- Create: `lib/core/posts/post/src/types/post_core_data.dart`
- Create: `lib/core/posts/post/src/types/booru_post_data.dart`
- Create: `lib/core/posts/post/src/types/unified_post.dart`
- Create: `lib/core/posts/post/src/types/stored_post_snapshot.dart`
- Create: `lib/core/posts/post/src/data/stored_post_codec.dart`
- Modify: `lib/core/posts/post/types.dart`
- Test: `test/core/posts/post/stored_post_codec_test.dart`

- [ ] Add tests proving a fully populated common post round-trips IDs, dates, every media URL, media variants, aspect ratios, dimensions, hash, duration, sound, typed tag groups, rating, nullable statistics, relationships, uploader, source, status, and metadata.
- [ ] Add tests proving absent optional fields remain `null`, maps contain only JSON-safe values, malformed common data returns a typed decode failure, and unsupported custom versions preserve common data with `UnknownPostData`.
- [ ] Run `fvm flutter test test/core/posts/post/stored_post_codec_test.dart`; confirm failure because the new model does not exist.
- [ ] Implement `PostOrigin`, `PostOriginSnapshot`, `PostCoreData`, `BooruPostData`, `EmptyPostData`, `LegacyPostData`, `UnknownPostData`, `UnifiedPost`, `StoredPostSnapshot`, `BooruPostDataCodec`, and `StoredPostDecodeResult`.
- [ ] Implement normalization of `sourceHost` from scheme/host/port and the common JSON codec. Keep legacy getters on `UnifiedPost` delegated to `PostCoreData` so existing shared UI can consume it as `Post`.
- [ ] Export the new contracts, format the batch, and rerun the focused test.
- [ ] Commit with `feat(posts): add unified post snapshot model`.

## Task 2: Add origin resolution and registry-owned post capabilities

**Files:**

- Create: `lib/core/posts/post/src/types/post_origin_resolution.dart`
- Create: `lib/core/posts/post/src/data/post_origin_resolver.dart`
- Create: `lib/core/posts/post/src/types/booru_post_presentation.dart`
- Create: `lib/core/posts/post/src/types/booru_post_capability.dart`
- Modify: `lib/core/boorus/engine/src/booru_repository.dart`
- Modify: `lib/core/boorus/engine/src/booru_builder.dart`
- Modify: `lib/core/boorus/engine/src/booru_engine.dart`
- Modify: `lib/core/boorus/engine/src/providers.dart`
- Modify: `lib/core/posts/post/types.dart`
- Test: `test/core/posts/post/post_origin_resolver_test.dart`
- Test: `test/core/posts/post/booru_post_capability_test.dart`

- [ ] Add resolver cases for an exact valid profile-ID hint, stale hint with one engine/host match, ambiguous engine/host matches, removed profile, mismatched host, and mismatched engine.
- [ ] Add capability tests proving codec/presentation selection requires both matching origin engine and compatible payload type; mismatch selects `GenericPostPresentation`.
- [ ] Run both focused tests and observe failures.
- [ ] Implement `PostOriginResolver` with exact-hint validation followed by normalized engine/host matching. Return `AmbiguousPostOrigin` rather than selecting the first match.
- [ ] Add `BooruPostCapability(codec, presentation)` to `BooruEngine`; expose it through repository providers without a central engine switch.
- [ ] Add `GenericPostPresentation`, whose details use only `PostCoreData` and whose grid additions are empty.
- [ ] Format and rerun both tests.
- [ ] Commit with `feat(posts): register post codecs and presentations`.

## Task 3: Migrate low-variance engine data to typed payloads and codecs

**Files:**

- Create: `lib/boorus/gelbooru_v1/posts/post_data.dart`
- Create: `lib/boorus/gelbooru_v1/posts/post_codec.dart`
- Create: `lib/boorus/hybooru/posts/post_data.dart`
- Create: `lib/boorus/hybooru/posts/post_codec.dart`
- Create: `lib/boorus/zerochan/posts/post_data.dart`
- Create: `lib/boorus/zerochan/posts/post_codec.dart`
- Create: `lib/boorus/gelbooru/posts/post_data.dart`
- Create: `lib/boorus/gelbooru/posts/post_codec.dart`
- Create: `lib/boorus/gelbooru_v2/posts/post_data.dart`
- Create: `lib/boorus/gelbooru_v2/posts/post_codec.dart`
- Create: `lib/boorus/moebooru/posts/post_data.dart`
- Create: `lib/boorus/moebooru/posts/post_codec.dart`
- Modify: each corresponding `*_builder.dart`, `posts/parser.dart`, `posts/providers.dart`, and `posts/types.dart`
- Test: `test/boorus/posts/low_variance_post_codec_contract_test.dart`

- [ ] Add one parameterized contract case per engine. Gelbooru V1, Hybooru, Zerochan, and Gelbooru use `EmptyPostData`; Gelbooru V2 preserves `hasNotes`; Moebooru preserves `largeImageUrl`.
- [ ] For every case assert API fixture → `UnifiedPost` → `StoredPostSnapshot` → `UnifiedPost` equality, including `origin` and all common fields.
- [ ] Run the contract test and observe the missing registrations.
- [ ] Add typed payloads, converters from current engine posts, codecs, and capability registrations. Parsers may keep returning legacy post classes in this transitional commit, but the converter must be the only path used by the contract test.
- [ ] Format and run the contract test plus the existing parser/repository tests for these engines.
- [ ] Commit with `refactor(posts): add low variance engine codecs`.

## Task 4: Migrate media- and metadata-rich engine data

**Files:**

- Create: `lib/boorus/anime-pictures/posts/post_data.dart`
- Create: `lib/boorus/anime-pictures/posts/post_codec.dart`
- Create: `lib/boorus/eshuushuu/posts/post_data.dart`
- Create: `lib/boorus/eshuushuu/posts/post_codec.dart`
- Create: `lib/boorus/hydrus/posts/post_data.dart`
- Create: `lib/boorus/hydrus/posts/post_codec.dart`
- Create: `lib/boorus/nozomi/posts/post_data.dart`
- Create: `lib/boorus/nozomi/posts/post_codec.dart`
- Create: `lib/boorus/pixiv/posts/post_data.dart`
- Create: `lib/boorus/pixiv/posts/post_codec.dart`
- Create: `lib/boorus/philomena/posts/post_data.dart`
- Create: `lib/boorus/philomena/posts/post_codec.dart`
- Modify: each corresponding `*_builder.dart`, `posts/parser.dart`, `posts/providers.dart`, `posts/types.dart`, and `posts/widgets.dart`
- Test: `test/boorus/posts/rich_post_codec_contract_test.dart`

- [ ] Add contract fixtures covering AnimePictures tag count and numeric/type status; Eshuushuu categorized tags, large URL, favorite state/count, and Bayesian rating; Hydrus own-favorite; Nozomi tag sets/aspect ratios; Pixiv illustration/page/user/series/AI/restriction data; and Philomena description/counts/votes/representation URLs.
- [ ] Assert round-trip equality and absence preservation for each nullable engine field.
- [ ] Run the new test and observe failure.
- [ ] Add typed payloads, legacy converters, codecs, and capability registrations. Put generally reusable media variants, aspect ratios, tags, counts, and status in `PostCoreData`; retain only engine-only values in payloads.
- [ ] Format and run the new contract test plus existing Pixiv cached-details and pagination tests.
- [ ] Commit with `refactor(posts): add rich engine codecs`.

## Task 5: Migrate interaction-heavy engine data

**Files:**

- Create: `lib/boorus/danbooru/posts/post/src/danbooru_post_data.dart`
- Create: `lib/boorus/danbooru/posts/post/src/danbooru_post_codec.dart`
- Create: `lib/boorus/e621/posts/post_data.dart`
- Create: `lib/boorus/e621/posts/post_codec.dart`
- Create: `lib/boorus/sankaku/posts/post_data.dart`
- Create: `lib/boorus/sankaku/posts/post_codec.dart`
- Create: `lib/boorus/shimmie2/posts/post_data.dart`
- Create: `lib/boorus/shimmie2/posts/post_codec.dart`
- Create: `lib/boorus/szurubooru/posts/post_data.dart`
- Create: `lib/boorus/szurubooru/posts/post_codec.dart`
- Modify: corresponding builders, parsers, providers, type barrels, and widgets under each engine
- Test: `test/boorus/posts/interaction_post_codec_contract_test.dart`

- [ ] Add Danbooru coverage for vote totals, favorite count, approver, categorized tags, variants, pixel hash, and moderation state.
- [ ] Add e621 coverage for species/lore/invalid tags, description, source list, favorite state, and typed video variants.
- [ ] Add Sankaku coverage for native ID, favorite state/count, detailed tags, and general/meta groups; Shimmie2 coverage for lock/file/name/tooltip/favorites/score/notes/children/title/approval/privacy/trash/owner/votes/comments; Szurubooru coverage for own-favorite, aggregate counts, tag details, status, and pools.
- [ ] Run the contract test and observe failure.
- [ ] Implement typed payloads and JSON-safe codecs. Convert external DTO objects into owned primitive/value records before persistence; do not place DTO instances in snapshots.
- [ ] Register capabilities and format the batch.
- [ ] Run the contract test and existing engine-specific post/details tests.
- [ ] Commit with `refactor(posts): add interaction engine codecs`.

## Task 6: Replace exact generic post contexts with a validated non-generic context

**Files:**

- Modify: `lib/core/posts/details/src/types/inherited_post.dart`
- Modify: `lib/core/posts/details/src/types/post_details.dart`
- Create: `lib/core/posts/details/src/types/post_presentation_context.dart`
- Modify: `lib/core/posts/details/src/widgets/post_details_scope.dart`
- Modify: `lib/core/posts/details/types.dart`
- Modify: every engine details/listing widget returned by `rg 'InheritedPost<|PostDetails<' lib/boorus lib/core`
- Test: `test/core/posts/details/post_presentation_context_test.dart`

- [ ] Add widget tests proving common UI reads the current `Post`, a compatible engine widget reads `D extends BooruPostData`, and an incompatible payload yields generic presentation rather than a cast exception.
- [ ] Run the focused test and observe failure against the generic contexts.
- [ ] Make `InheritedPost` and `PostDetails` non-generic. Add `PostPresentationContext` with current post, validated presentation, optional resolved config, and `D? data<D extends BooruPostData>()`.
- [ ] Update each exact-type call site to read common values from `Post` and engine values through the validated payload accessor. Engine widgets must not cast the surrounding post list.
- [ ] Run `rg 'InheritedPost<|PostDetails<' lib` and require no matches.
- [ ] Format and run the focused details test plus existing details tests.
- [ ] Commit with `refactor(posts): use validated post presentation context`.

## Task 7: Build the shared card renderer and engine additions

**Files:**

- Create: `lib/core/posts/listing/src/widgets/post_grid_item.dart`
- Modify: `lib/core/posts/listing/src/widgets/default_image_grid_item.dart`
- Modify: `lib/core/posts/listing/src/widgets/sliver_post_grid_image_grid_item.dart`
- Modify: `lib/core/posts/listing/src/widgets/post_grid.dart`
- Modify: `lib/boorus/danbooru/posts/listing/src/default_danbooru_image_grid_item.dart`
- Modify: engine builders/presentations that currently supply quick actions or overlays
- Test: `test/core/posts/listing/post_grid_item_test.dart`

- [ ] Add a table-driven widget test rendering the same post through search, favorites, bookmarks, and feed containers. Assert identical media URL/quality, aspect ratio, content blocking, video/GIF, translation, comments, relationships, AI, sound, duration, score, and tag-preview semantics.
- [ ] Add tests proving Danbooru-only overlays and native quick favorite appear for compatible Danbooru data, never for incompatible/fallback data, while feed `NEW` and bookmark group decorations remain externally composable.
- [ ] Run the focused test and observe failure because containers still build separate cards.
- [ ] Implement `PostGridItem` as the only semantic post-card renderer. Let `BooruPostPresentation` add optional overlay/quick-action content and let callers wrap orthogonal container badges.
- [ ] Route `DefaultImageGridItem`, sliver grids, and Danbooru's specialized item through `PostGridItem`; remove duplicated decisions from wrappers.
- [ ] Format and run listing tests.
- [ ] Commit with `refactor(posts): share booru aware post cards`.

## Task 8: Build the dynamic mixed-booru viewer

**Files:**

- Create: `lib/core/posts/details/src/widgets/mixed_post_details_page.dart`
- Create: `lib/core/posts/details/src/widgets/post_page_presentation_scope.dart`
- Modify: `lib/core/posts/details/src/widgets/post_details_page_scaffold.dart`
- Modify: `lib/core/posts/details/src/widgets/post_details_controller.dart`
- Modify: `lib/core/posts/details/src/widgets/post_details_item.dart`
- Modify: `lib/core/posts/details/src/widgets/post_media.dart`
- Modify: `lib/core/posts/details/src/providers/video_url_provider.dart`
- Modify: `lib/core/posts/details/src/types/media_url_resolver.dart`
- Modify: `lib/core/posts/details/routes.dart`
- Test: `test/core/posts/details/mixed_post_details_page_test.dart`

- [ ] Add a widget test with Danbooru → e621 → Pixiv → `UnknownPostData`. Swipe pages and assert each page receives its own presentation, media resolver, host/profile provider, toolbar, details sections, and generic warning for the last page.
- [ ] Record the initial value of `currentBooruConfigProvider`; assert it does not change after any page transition or action.
- [ ] Add tests that zoom, load-original, video playback state, details-sheet state, slideshow progression, back navigation, and swipe position continue across engine boundaries.
- [ ] Run the focused test and observe failure against the homogeneous scaffold.
- [ ] Implement one stable `MixedPostDetailsPage` controller stack. Resolve `PostOrigin` per active page; install read-only config/repository overrides in `PostPagePresentationScope`; pass explicit page configuration to media builders so adjacent swipe pages cannot inherit stale providers.
- [ ] On missing/ambiguous config, engine mismatch, or unknown payload, keep common media and navigation and select `GenericPostPresentation`.
- [ ] Format and run mixed-viewer and existing lazy-pager tests.
- [ ] Commit with `feat(posts): add dynamic mixed booru viewer`.

## Task 9: Move engine viewer behavior into presentations

**Files:**

- Modify: all engine `*_builder.dart` files registered in `lib/core/boorus/engine`
- Modify: engine post-details page/UI-builder/provider/widget files under `lib/boorus/*/posts/details/`
- Modify: engine post widgets under `lib/boorus/*/posts/widgets.dart` and `lib/boorus/*/posts/`
- Modify: `lib/core/posts/details/src/widgets/default_post_details_page.dart`
- Test: `test/boorus/posts/post_presentation_contract_test.dart`

- [ ] Add one presentation contract case for every registered image-post engine. Assert the presentation accepts its payload, rejects a different engine payload, builds static details without a network call, and exposes the same gestures/wrappers/actions as its current native page.
- [ ] Run the contract test and observe missing or incomplete presentations.
- [ ] Move details builders, viewer wrappers, gesture hooks, media resolution, favorites/votes/comments/notes/pool actions, and engine-specific toolbar behavior into each registered `BooruPostPresentation`.
- [ ] Reduce old engine details pages to thin route adapters that invoke `MixedPostDetailsPage`, then remove adapters with no remaining callers.
- [ ] Format and run the presentation contract and engine details tests.
- [ ] Commit with `refactor(posts): register native post presentations`.

## Task 10: Route search and server favorites through unified posts and shared UI

**Files:**

- Create: `lib/core/posts/post/src/data/unified_post_repository.dart`
- Modify: `lib/core/posts/post/src/data/providers.dart`
- Modify: `lib/core/posts/listing/src/widgets/post_grid.dart`
- Modify: `lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart`
- Modify: `lib/core/posts/favorites/src/data/repository.dart`
- Modify: engine search/favorites route builders under `lib/boorus/`
- Test: `test/core/posts/post/unified_post_repository_test.dart`
- Test: `test/core/posts/favorites/favorite_post_presentation_test.dart`

- [ ] Add repository tests proving page order, pagination metadata, and errors are unchanged while each legacy result is converted with the requesting profile's `PostOrigin`.
- [ ] Add search/favorites widget tests proving both open the shared card and mixed viewer and keep correct origin/profile actions.
- [ ] Run both tests and observe failure.
- [ ] Add the temporary repository adapter and a provider that captures engine results as `UnifiedPost`. Migrate search and favorites consumers, then remove favorite-specific card/viewer forks.
- [ ] Format and run post repository, listing, favorites, and engine search tests.
- [ ] Commit with `refactor(posts): unify search and favorite presentation`.

## Task 11: Replace bookmark posts with versioned post snapshots

**Files:**

- Modify: `lib/core/bookmarks/src/types/bookmark.dart`
- Modify: `lib/core/bookmarks/src/data/hive/bookmark_hive_object.dart`
- Modify: `lib/core/bookmarks/src/data/bookmark_convert.dart`
- Modify: `lib/core/bookmarks/src/data/hive/repository.dart`
- Modify: `lib/core/bookmarks/src/services/bookmark_library_service.dart`
- Modify: `lib/core/bookmarks/src/providers/bookmark_provider.dart`
- Modify: `lib/core/bookmarks/src/pages/bookmark_page.dart`
- Modify: `lib/core/bookmarks/src/pages/bookmark_details_page.dart`
- Modify: `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`
- Test: `test/core/bookmarks/bookmark_snapshot_migration_test.dart`
- Test: `test/core/bookmarks/bookmark_details_page_test.dart`

- [ ] Add migration tests from the current Hive object to `BookmarkEntry(localId, createdAt, updatedAt, snapshot)`, asserting unchanged local ID, timestamp semantics, booru identity, and group references.
- [ ] Add page tests proving a complete snapshot opens native card/viewer UI without fetching; legacy/malformed data shows cached generic UI and warning; successful retry upgrades the snapshot without changing local ID or group membership.
- [ ] Run both tests and observe failure.
- [ ] Persist snapshots in the Hive object with a schema-version discriminator and a read adapter for existing rows. Decode entries to the unified runtime post in providers.
- [ ] Replace bookmark card/details code with shared `PostGridItem` and `MixedPostDetailsPage`. Keep bookmark context menus/group affordances as wrappers.
- [ ] Format and run all `test/core/bookmarks` tests.
- [ ] Commit with `refactor(bookmarks): persist native post snapshots`.

## Task 12: Replace cached feed posts with versioned post snapshots

**Files:**

- Modify: `lib/core/search/subscriptions/src/types/search_post_preview.dart`
- Modify: `lib/core/search/subscriptions/src/data/hive/search_post_preview_hive_object.dart`
- Modify: `lib/core/search/subscriptions/src/services/search_refresh_service.dart`
- Modify: `lib/core/search/subscriptions/src/services/feed_history_session.dart`
- Modify: `lib/core/search/subscriptions/src/pages/following_feeds_page.dart`
- Modify: `lib/core/search/subscriptions/src/widgets/feed_post_thumbnail.dart`
- Test: `test/core/search/subscriptions/feed_post_snapshot_test.dart`
- Test: `test/core/search/subscriptions/following_feed_test.dart`

- [ ] Add migration and round-trip tests proving cached order, source membership, refresh cursor/checkpoint, retained limit, history paging, deduplication, and `NEW` state remain unchanged while every row carries `StoredPostSnapshot`.
- [ ] Add rendering tests proving complete snapshots use native grid/viewer presentation offline and invalid snapshots remain swipeable in generic UI.
- [ ] Run the focused tests and observe failure.
- [ ] Store/decode snapshots at the existing feed persistence boundary. Route cards and opening through the shared grid/viewer and remove the current global-profile update from feed opening.
- [ ] Keep `NEW` as a feed-owned decoration outside `PostGridItem`.
- [ ] Format and run all subscription tests, including Pixiv cached-details and pagination tests.
- [ ] Commit with `refactor(feeds): persist native post snapshots`.

## Task 13: Add bookmark backup version 2 and localized version-1 import

**Files:**

- Modify: `lib/core/backups/sources/bookmark_backup_data.dart`
- Modify: `lib/core/backups/sources/bookmark_backup_codec.dart`
- Modify: `lib/core/backups/sources/bookmarks_source.dart`
- Modify: `lib/core/backups/sources/bookmark_import_planner.dart`
- Modify: `lib/core/backups/sources/bookmark_import_service.dart`
- Test: `test/core/backups/bookmark_backup_codec_test.dart`
- Test: `test/core/backups/bookmark_import_planner_test.dart`
- Test: `test/core/backups/bookmark_import_service_test.dart`

- [ ] Add a version-2 golden-shaped test containing full origin/common/custom snapshot data, timestamps, and groups; assert decode/encode equality and group references.
- [ ] Keep a version-1 fixture and assert it imports as `PostCoreData + LegacyPostData` without invented engine fields. Assert conflict/scoped-export/rollback behavior is unchanged.
- [ ] Run the backup tests and observe failure on version 2.
- [ ] Set new exports to version 2. Add one version dispatch in `BookmarkBackupCodec`; keep the v1 adapter confined to that file and shared snapshot construction helpers.
- [ ] Do not dual-write v1 fields. If v1 import requires changes outside backup codec/import boundaries, stop this task and request explicit review before dropping compatibility.
- [ ] Format and run all bookmark backup/import tests.
- [ ] Commit with `feat(backups): store versioned bookmark snapshots`.

## Task 14: Make `Post` concrete and remove the transitional hierarchy

**Files:**

- Modify: `lib/core/posts/post/src/types/post.dart`
- Remove: `lib/core/posts/post/src/types/unified_post.dart`
- Remove: `lib/core/posts/post/src/types/simple_post.dart`
- Modify: every engine parser/repository/provider/type file still returning an engine post class
- Remove: legacy engine post classes after their parsers construct `Post(core, origin, booruData)` directly
- Remove: bookmark/feed reduced post conversion types and files that define `BookmarkPost` or `CachedFeedPost`
- Modify: tests and fixtures still constructing legacy classes
- Test: `test/core/posts/post/concrete_post_contract_test.dart`

- [ ] Add a compile/runtime contract that every registered image-post parser returns exact runtime type `Post`, preserves its typed payload, and can pass through snapshot encode/decode.
- [ ] Run the contract and observe legacy runtime types.
- [ ] Move `UnifiedPost` implementation into concrete `Post`, update constructors and repository signatures, and make engine parsers build it directly.
- [ ] Delete temporary legacy converters, engine `Post` subclasses, `SimplePost`, `BookmarkPost`, and `CachedFeedPost`; convert demo/preview objects to construct or contain `Post`.
- [ ] Run `rg 'UnifiedPost|BookmarkPost|CachedFeedPost|extends SimplePost|implements Post|InheritedPost<|PostDetails<' lib test` and require no shipped hierarchy matches; allow only historical prose in the spec/plan.
- [ ] Format and run the concrete contract, all engine codec contracts, and all affected tests.
- [ ] Commit with `refactor(posts): use one concrete runtime post`.

## Task 15: Add localized fallback messaging and verify the complete behavior

**Files:**

- Modify: `packages/i18n/translations/en-US.json`
- Regenerate: `packages/i18n/lib/src/gen/strings.g.dart`
- Regenerate: `packages/i18n/lib/src/gen/strings_en_US.g.dart`
- Modify: `lib/core/posts/details/src/widgets/mixed_post_details_page.dart`
- Create: `docs/post_architecture.md`
- Modify: `docs/work/in-progress/POST-001-unified-post-model-and-viewer.md`
- Move after verification: `docs/work/in-progress/POST-001-unified-post-model-and-viewer.md` → `docs/work/done/POST-001-unified-post-model-and-viewer.md`
- Test: `test/core/posts/details/post_fallback_presentation_test.dart`

- [ ] Add tests for localized warnings covering missing profile, ambiguous profile, unavailable engine, malformed data, unsupported version, removed upstream post, and refresh failure. Assert cached media, tags, navigation, zoom, download, and share remain available; retry appears only when a profile resolves.
- [ ] Run the fallback test and observe missing strings/states.
- [ ] Add concise localized messages and the warning/retry UI, run `./gen.sh`, format generated Dart only through the repository's generation workflow, and rerun the fallback test.
- [ ] Update architecture documentation with the stable model, snapshot, codec, presentation, origin-resolution, and mixed-viewer boundaries.
- [ ] Run focused suites: `fvm flutter test test/core/posts test/core/bookmarks test/core/search/subscriptions test/core/backups` plus the engine codec/presentation contract tests.
- [ ] Run `fvm flutter analyze`, full `fvm flutter test`, and `git diff --check`. Investigate any failure; rerun a failing named test before identifying it as unrelated or flaky.
- [ ] Use Maestro on the Android emulator: open a mixed sequence containing Danbooru, e621, Pixiv, and a fallback snapshot; verify visible engine-specific overlays/actions change on swipe, generic warning remains navigable, global profile stays unchanged, video/zoom/details/slideshow work, bookmark groups remain intact, and feed `NEW` remains external.
- [ ] Record exact automated and live evidence in the queue task. Move it to `done/` only when every acceptance criterion has evidence.
- [ ] Commit with `docs(posts): record unified viewer verification`.
