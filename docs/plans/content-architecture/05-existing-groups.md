# Stage 05: move existing source Groups to shared contracts

**Issue:** #156. **Branch:** `maintenance/156-shared-source-groups`.
**Base:** reviewed #143 candidate with #154/#155/#142.
**Goal:** existing Danbooru Pool/Related and Szurubooru Pool behavior runs through the new contracts without a visual redesign.
**Final reviewer:** independent Astra High. Read the [approved contract](approved-contract.md), `docs/post_architecture.md` and current Group tests.

## Source map

Inspect and adapt `lib/boorus/danbooru/pools/` including `bookmarks.dart`, existing Pool repository/providers/detail content and gallery checkpoint widgets; `lib/boorus/danbooru/posts/related/related_gallery.dart`; `lib/core/posts/related/related_family.dart` and `related_posts_order.dart`; the current Szurubooru Pool capability and engine registration; `lib/core/posts/details/src/types/viewer_entry.dart` and adjacent sequence/capability/binding files; `lib/core/posts/details_pageview/src/post_details_page_view.dart`; `lib/core/posts/details/src/widgets/post_details_page_scaffold.dart`; Group card/cover/picker adapters and bookmark grid projection.

Use repository search to locate the actual Szurubooru provider/route registrations before editing; do not invent a new engine implementation folder if it already exists. Add source adapters beside each engine's existing Pool/Related code. Suggested new source tests live in `test/core/content/existing_group_adapters_test.dart`; extend existing Pool/Related gallery, mixed-entry navigation and grouping tests in their current folders.

## Task 1: adapt source data and ordering

**Consumes:** #154 Group source/metadata/member values and #143 access. **Produces:** working adapters for currently supported source Groups.

1. Map each real Pool to group/pool:<id>; category is metadata only. Map Related through the existing canonical parent/anchor reference to group/related:<id>. Do not introduce a second family discovery rule or traverse all ancestors/siblings speculatively.
2. Reuse existing Summary/Details fetchers. Preserve native description, category, member count and known-empty versus unknown values. Keep member-union filter tags in the local index, not native Summary.tags.
3. Map authoritative Pool member order to sourcePosition before filtering/loading. Batched Post responses may arrive reordered or omit IDs; restore manifest order and preserve missing positions. Already loaded Posts populate resolved without per-Post re-fetch.
4. Related oldest/newest maps to the existing source query; do not infer narrative chronology or force sourcePosition when only display sorting is known. Preserve #155's saved Related preference through this adapter.
5. Szurubooru reuses its actual source capability and order; do not claim Danbooru-only API behavior. Unknown fields remain unknown instead of fabricated values.
6. Tests cover Pool category transition retaining identity, empty/missing members, duplicate membership where supported, out-of-order API batches, partial blacklist results and same IDs on different installations/accounts.

## Task 2: one registration and one mixed-viewer entry path

1. Replace legacy Pool-specific content dispatch with the registered Group capability and thin engine adapters. Keep stable route/link compatibility. Remove obsolete wrappers only after all callers/tests have moved; do not keep two independent routers.
2. Preserve ViewerEntrySequence outer occurrence IDs, append-only source updates, grid-owned projection and mapping to real Posts. Repeated groups get independent route state. No global profile switch.
3. Group grid/loading/error pages publish no active Post, inherited Post scope, zoom transform, video control or vertical media-dismiss action. Clear previous media actions before showing the Group; Back stays available even when source access is unavailable.
4. Keep existing content-owned navigation header, status inset ownership, Pool title/description scrolling and local sort control. No #146-#148 header/system-bar refactor here.
5. Test a mixed sequence Post -> Pool -> Related -> Post, including removed profile, loading failure and retry. Navigation remains valid and no stale Post action can target a neighbor.

## Task 3: preserve the existing grid/timeline UX

1. Keep Danbooru Pool header/description + Post Timeline, Related grid/timeline + ordinary Post viewer, and Szurubooru's current equivalent. No media-first Related Overview, extra thumbnail strip or Timeline overflow switch.
2. Preserve PageStorage/route-local sort and scroll checkpoints per occurrence. Restoring deeper pages reloads only the previously visited extent; user input cancels restoration. Inactive grids must not react to shortcuts or auto-pagination.
3. Opening a member retains the existing normal Post viewer route above the gallery with the actual member sequence. Back restores gallery offset and outer page; avoid duplicate Hero animations and source-grid exit adjustments.
4. Gallery selection still suppresses outer paging gestures/shortcuts. Keep bulk actions source-aware, blacklist policy and selected IDs stable after filtering.
5. Preserve #68's existing grouping projection, five-result lookahead behavior and counters exactly. #134 new Related grouping is not implemented merely because a new family adapter exists.
6. Test first/last bounds, repeated occurrences, loading-to-content header measurement, selection, Back, account changes and late member completion.

## Task 4: bridge local Bookmarks and covers safely

1. Connect header/group actions to #155's generic saved Group path and existing Kurumi picker. Old Pool/Related records open through migrated references. Preserve Added sorting, strict local filtering, membership counts and source-profile hints.
2. Cover rendering must stop manufacturing an actionable id-0 Post. Extract only the media URL/variant/geometry descriptor required by the existing thumbnail cache/resolver; no general media framework or quality-policy rewrite.
3. Cover source and policy are checked before requests. A policy-incompatible cached cover must not leak through a generic fallback. Do not pass Group metadata to Post download/favorite actions.
4. Keep legacy native links working. Generalized portable Group links validate the same references and do not embed local IDs/auth. Sharing a member uses its existing Post link.
5. Tests cover Group bookmarks after cold migration, shared media-cache use, cover-policy changes, no spurious bookmark identity from a cover and preservation of Related order on refresh.

## Task 5: remove compatibility paths only when unused

Search for PoolViewerEntry/RelatedViewerEntry, ViewerEntryContentCapability and CollectionBookmark usages. Preserve intentional old-wire decoders and thin route compatibility, remove runtime duplication after verified replacement, and document the final dispatch ownership. No unrelated cleanup or mass renaming of working UI components just to make names uniform.

Update `docs/post_architecture.md` and `docs/bookmark_groups.md` to describe actual implemented runtime behavior, while retaining old design docs as history with the approved contract as the current design authority.

## Verification and exit

Run all new adapter tests plus existing Pool, Related, mixed-viewer, bookmark, selection and source/profile tests; run formatting, analysis and the full regression. On a leased Android emulator, exercise Pool/Related/Szurubooru paths with available real services, repeated outer occurrences, source removal, selection, deep scroll restore, narrow width, large text, system Back and rotation. Source unavailability is recorded honestly; a mock test does not replace a required native path check.

Lower-cost agents may map legacy callers, add fixture matrices and adapt simple card metadata in disjoint files. The lead owns source ordering, registry cutover, identity/profile scope and sequence state. Independent Astra High reviews the final candidate, specifically whether the apparently UI-neutral refactor changes gallery navigation, request count or persisted identity.

No stage exit with a second active Group implementation or stale Post actions. Deliver a per-issue handoff. Keep #156 open pending authorized shared develop publication.
