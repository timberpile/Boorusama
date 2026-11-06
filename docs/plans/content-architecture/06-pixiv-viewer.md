# Stage 06: Pixiv Work/Page presentation

**Issue:** #140. **Branch:** `feature/140-pixiv-work-viewer`.
**Base:** reviewed #156 candidate. Existing #137 Page-index behavior is mandatory.
**Goal:** native Work listings and the approved Image View/Overview composition, using real Page Posts and the existing mixed viewer.
**Final reviewer:** independent Astra High.

## Read these exact design references

- [Approved contract](approved-contract.md), especially metadata/member/access/viewer boundaries.
- `docs/designs/mockups/2026-11-04-viewer-interaction-lab.html` and `2026-11-04-content-design-lab.html`.
- `docs/designs/2026-11-04-viewer-interaction-review.md`, `2026-11-04-content-model-and-viewer-clarifications.md`.
- `docs/designs/2026-11-05-decision-02-work-page-ux-and-actions.md`, including the accepted hold-indicator geometry.
- Later accepted decisions in `docs/designs/2026-11-05-architecture-decision-series.md`; the new approved contract takes precedence over stale alternatives.

The user already selected image swipes for Pages and details swipes for whole Works. Do not restart a comparison between vertical reader/gallery alternatives. Do not use the rejected Related viewer prototype as a reference. Follow the actual app/Kurumi design, not a generic media mockup.

## Source and new-file map

Inspect `lib/boorus/pixiv/posts/` parser, Post data, repository, provider and query code; Pixiv listing routes/Explore/Favorites/artist pages and engine registration; `packages/booru_clients/lib/src/pixiv/pixiv_client.dart` and its current response types; the shared content source/controller from #154/#156.

Viewer boundaries: `lib/core/posts/details/src/types/viewer_entry.dart`, its sequence/source binding; `lib/core/posts/details_pageview/src/post_details_page_view.dart`; `lib/core/posts/details/src/widgets/post_details_page_scaffold.dart`; `post_details_item.dart`; `lib/core/widgets/interactive_viewer_extended.dart`; existing media presentation scopes, controls and download actions. Inspect the real DownloadPostButton painter and current share sheet before changing action geometry.

New source files should be Pixiv-owned, e.g. `lib/boorus/pixiv/works/work_source.dart`, `work_mapper.dart`, `work_presentation.dart`, `work_viewer.dart`. Shared additions are limited to the active-media bridge and reusable media-first composition genuinely required by more than one engine. Suggested tests: `test/boorus/pixiv/works/work_source_test.dart`, `work_listing_test.dart`, `work_viewer_test.dart`, plus `test/core/posts/details/group_media_binding_test.dart` at the actual current test root.

## Task 1: Work responses and native listing boundary

1. Add fixtures for single-page illustration, multi-page manga, missing intermediate original URL, restricted Work and Ugoira. Preserve genuine illustration ID, original zero-based page indices and declared page count from #137.
2. Map one source artwork to one Group Summary with key `work:<illustId>`. Page Post references remain `work-page:<illustId>:<originalIndex>` and all current Post snapshot fields/typed Pixiv data survive. Ugoira is one real animation Post, not a Group of frames.
3. Introduce only the small native Group/mixed listing capability needed by Pixiv screens. Do not change every PostRepository or Following's Post snapshots. Existing Post-only callers can retain their explicit projection until their UI deliberately uses native Works.
4. Bind the actual listing source/profile before emitting entries. Preserve ranking/search/favorites/artist source order, pagination and query semantics. Do not implement #83 search features or #124 remote writes.
5. Summary cards must not fetch details or all Pages. Preserve safe cover policy, declared direct member count and meaningful nulls. Avoid regrouping the same raw list independently in grid and viewer.
6. Test a mixed/native list returning Work 120 then 121, no page-flattening in that listing, stable keys across pagination, and no per-card detail requests.

## Task 2: share detail response and Page manifest

1. Adapt loadDetails/loadMembers to one access-scoped raw artwork envelope when the API already supplies both. Concurrent consumers share it; different profiles or policies do not.
2. Build GroupMember slots from original indices before filtering. Match resolved real Posts by stable Page key; missing media must not change any later key, synthetic compatibility ID, filename or declared count.
3. Test `[page 0, unavailable page 1, page 2]`, image metadata becoming available later, source failure and restricted responses. A selected unavailable slot has no neighboring Post action target. Existing provisional-media rules remain applicable; never invent original URLs.
4. Retain Work description/creators/tags at Work scope. Do not stamp a Work caption into PostDetailFacts as if it were page-specific evidence. Account bookmark state remains in its existing profile-scoped state system.

## Task 3: explicit active Page binding

1. Extend existing GroupViewerEntry/ViewerEntrySequence rather than creating a second full-screen viewer. Add ViewerMediaBinding and occurrence-local GroupViewerState from the contract.
2. The outer pager contains Works; the active inner member is a real Post for image/video, details, quality, share/download and scoped preloading. Direct Post entries still behave exactly as before.
3. Changing outer occurrence must clear the previous binding before displaying loading/error/grid content. A media-less Group has no inherited currentPost, zoom or playback action. Safe cached Post fallback may use existing offline policy but cannot grant remote mutations.
4. Two occurrences of Work 120 may share scoped source data but independently retain Page, overview scroll and bounded reading transforms. Route disposal releases controllers/listeners, and eviction retains only lightweight checkpoints.
5. Live append keeps established outer entries stable. Active source update must not replace the current route, reset the reading transform or leak another account's media settings.
6. Test repeated occurrences, rapid Work/Page transitions, delayed detail resolution, profile removal and mixed Post -> Work -> Pool navigation. No stale action, reordering or duplicate media fetch is allowed.

## Task 4: implement the approved composition and gesture ownership

1. Reuse the approved selected-image + Work-details composition, existing compact Work action area and Kurumi components. Image View is media-first; Overview shows the selected image and real Work metadata, not a second independent Page overview below it.
2. In portrait, do not duplicate the image or force an additional persistent thumbnail strip. Preserve aspect ratio, bounded layout and the original design's Image View/Overview switch. Landscape/short screens must retain reachable controls and scrolling metadata.
3. Horizontal image swipes change Pages only. Horizontal swipes in the details/Overview region move outer Works. Image boundary does not unexpectedly skip to the next Work; provide existing explicit outer navigation/accessibility paths.
4. Preserve image pan/pinch/zoom-edge behavior, text selection and vertical details scroll. Do not install a broad GestureDetector that steals these gestures. No two-finger special navigation. Test text selection, multi-touch, cancelled drags and diagonal gestures.
5. Viewer Controls on Open is evaluated once at route/session entry. Switching Work/Page or toggling Overview must not repeatedly reapply it or reset the Page's reading position.
6. Single-page Works retain distinct Work/Page identities but avoid redundant identical-looking controls. Page alternate actions stay accessible through the existing menu pattern.
7. Local Work bookmarking is completed by #141. Until that capability is connected, never render a Work-labelled action that silently saves a Page. Keep this staged candidate unreleased with clear capability gating rather than fake behavior.

## Task 5: Page and all-Page media operations

1. Normal Download uses the captured current Page Post. Hold/overflow offers Download All with existing queue/progress/cancel and original Page order/filenames. Missing/restricted Pages must not be counted as downloaded successes.
2. Use bounded member loading and existing request pacing; do not fetch every image to construct Overview. No recursive Manga Series downloader in this stage.
3. Work source URL uses the genuine illustration ID; image URL/bytes use the selected Page. Portable Work/Page sharing is completed with #141 on the common validated link path; do not fabricate page-native Pixiv URLs.
4. Keep action geometry: the hold chevron is decoration inside the existing fixed hit bounds, without shrinking/moving the main icon, changing padding or creating a second target. Long press cannot fire tap on release; overflow and semantics alternatives are mandatory.
5. Test download target capture during rapid swipes, cancelled all-Page enumeration, Ugoira behavior, quality upgrades without reset and no unauthorized remote favorite writes.

## Zoom compatibility and non-goals

Read #153's existing handoff from `feature/153-improve-aspect-aware-double-tap-zoom`: Classic-only, automatic downward snapping and 2x portrait Comic detail zoom are agreed. Do not reimplement zoom or silently merge that branch. The local agent can verify its current candidate separately; any branch combination requires the repository's explicit integration authorization and a fresh regression of the combined runtime candidate. The current core refactor can proceed without waiting for that separate merge.

No Related redesign, Manga Series UI, Pixiv username search, popularity filtering, recommendations, public/private mutation UI, toolbar editor, Penpot completion or global header redesign.

## Verification and delegation

Run current Pixiv parser/Page identity tests, new source/listing/media-binding/widget tests, Post details/media/download/share regressions, formatting, analysis, changed package suite if applicable and complete regression. A leased Android acceptance uses real authenticated Pixiv reads: single/multi-page Works, Ugoira, a missing/unavailable case where reproducible, rapid swipes, rotation, Back, large text, offline restore and mixed-origin neighboring entries. Do not create/remove server favorites during read-only acceptance.

Lower-cost agents may write fixtures, map listing callsites and implement localized static metadata sections in isolated files after the lead fixes interfaces. Gesture arbitration, active media/profile binding, stale-state prevention and download targeting stay with the high-capability lead. Independent Astra High reviews the complete candidate and Android evidence. No unverified mockup is accepted as device proof. Deliver #140's handoff before #141.
