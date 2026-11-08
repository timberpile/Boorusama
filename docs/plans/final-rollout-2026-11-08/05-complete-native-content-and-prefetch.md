# Plan 05: complete Pixiv, nhentai and shared timeline integration

Read the [lead handoff](../../handoffs/final-rollout-remediation-2026-11-08.md). The current #140/#141/#157 branches contain reviewed foundations, not finished app features. The user now requires completion of the production paths. Do not stop at another mapper/provider checkpoint.

## Prerequisites and authoritative design

Reconcile the common baseline first: URL-cache reuse, correct current reading-context resolution, Pixiv media headers, action actor capture, Group refresh/restoration, recursive local deletion and the corrected shared picker. Preserve v10 compatibility and the accepted Classic-only zoom from `develop`.

Read the full existing plans and approved contract, not just issue bodies:

- [Stage 06: Pixiv viewer](../content-architecture/06-pixiv-viewer.md)
- [Stage 07: Pixiv Bookmarks](../content-architecture/07-pixiv-bookmarks.md)
- [Stage 08: nhentai](../content-architecture/08-nhentai.md)
- [Approved content contract](../content-architecture/approved-contract.md)
- Existing #140, #141 and #157 issue-owned handoffs.

The already-approved UX is Image View/Overview, with image-region swipes changing Pages and details-region swipes changing Works. A vertical continuous reader, a generic Pool grid as the new Pixiv default, and a rejected Related prototype are not substitutes. Latest review requirement is an actual independent Sol High; older Astra wording does not reopen model choice.

## A. Complete #140: native Pixiv Works in the normal app

### Source/listing integration

Use `lib/boorus/pixiv/works/{work_mapper,work_source,providers}.dart` as the starting foundation. Register the actual Group capability/presentation and wire ordinary Search, Explore/ranking, Following feed where applicable, Favorites and artist listing entry points according to their existing native APIs. Post-only compatibility consumers retain their deliberate projection until migrated; do not force every PostRepository or cached Following record into a new model.

One illustration/manga becomes one Work entry identified by the real illustration ID. Members are the original Page Posts, with their original zero-based indices, declared counts and unavailable slots. Ugoira remains a genuine animation Post. Listing cards consume the list response, not a per-card detail request. Do not regroup the same data independently for the grid and viewer.

Retain source pagination/continuation even when a batch has no visible entries, including #161 fixes. Preserve ranking mode/date, query, privacy and captured account boundaries. Summary/Details/member reads must share the existing access-scoped envelope and honor refresh invalidation without accepting stale seeds.

### Viewer, gestures and media actions

Connect the existing Mixed Viewer to an occurrence-local active Page binding; do not build a nested full viewer or fabricate a Group as a Post. The current real Page owns image/video rendering, geometry, quality, details, bounded preloading and media actions. A loading/error/unavailable Group clears its previous Page action target before any further input.

Implement the approved Image View/Overview composition with existing Kurumi/app components. Preserve Page pan/pinch/double-tap transforms, Page versus Work gesture ownership, text selection and vertical metadata scrolling. Image boundary swipes must not unexpectedly change the outer Work. Repeated occurrences may share source data but retain independent Page, reading position and overview checkpoints.

Normal Download targets the captured Page; hold/overflow offers bounded Download All with the existing queue, progress/cancellation and original Page filenames. A missing/restricted Page is not a successful download. Work metadata remains Work-level; do not copy its caption into Page-specific facts. Preserve Ugoira handling, source links and existing server Favorite semantics without adding new remote mutations.

### Completion evidence

Tests must drive actual registered listings and the ordinary Mixed Viewer, not only WorkSource directly. Include single/multi-page Works, unavailable middle Page, Ugoira, two occurrences, rapid Page/Work transitions, delayed responses, token rotation/revocation, quality upgrades, orientation, Back and bounded media requests. Prove the UI can reach these paths without test-only provider overrides.

## B. Complete #141: independent Work/Page Bookmarks and sharing

`bookmark_targets.dart` supplies frozen drafts, but the current generic picker and action surface still need production wiring.

1. Extend the existing sealed picker request/mutation session with the small generic unsaved ContentGroup path it needs. Do not cast a Work into a Pool, pass provisional ID zero as a saved record ID, or introduce a second picker/storage service.
2. Normal Bookmark opens the shared picker for the whole Work. Hold/overflow exposes Work and Current Page. The decorative alternate-action marker stays inside existing icon/touch bounds; it does not shift the main icon or create a second tiny hit target. Hold release must not also trigger the normal tap.
3. Capture target identity and actor before opening the choice/picker. Later swipes never redirect the pending save. Reuse the corrected Recent, group creation, hierarchy and Back behavior from Plan 03. Preserve explicit operation revocation and no duplicate late writes.
4. Work save creates one Group record and zero implicit Page records. Page save creates only that real Page PostBookmark. Membership indicators, selection, removal, Undo, offline snapshots and shared local IDs remain independent. Single-page Works still have distinct identities without redundant normal controls.
5. Wire the existing Share Sheet to a native Work URL, current Page media and separate portable Boorusama Work/Page links/files. Reuse `.bslink` v1 and the deployed URI codec. Never expose synthetic numeric Page IDs as illustration IDs or include local profile IDs/tokens in portable links.
6. Round-trip Work/Page records with mixed Danbooru Post/Pool/Related and inaccessible sources through v10, without profiles, then attach a compatible profile using Plan 01. Do not mutate remote Pixiv Favorites from a local Bookmark action.

Gate completion on actual toolbar/picker/share/open paths, deferred target tests, real Hive/restart/Undo, narrow/large-text UI and ordinary Android save/reopen/remove/share. Foundation test counts alone are not completion.

## C. Complete #157: native nhentai Gallery/Page feature

The package foundation under `packages/booru_clients/lib/src/nhentai/` must be integrated with `lib/boorus/nhentai/`, the existing generated source configuration/registration, Group/native listings and shared media-first viewer. Do not register an engine with dead routes or leave Gallery/Page Bookmark controls as stubs.

### Correct foundation findings before registration

**C3: catalogue-write cancellation race.** `_warm` awaits store mutations through `_wait`, which races them against cancellation. A cancelled caller can release `_catalogTail` before an already-started `upsertTags`/`writeCheckpoint` finishes. A later operation can persist a newer checkpoint and then be overwritten by the old completion.

Keep the internal serialization barrier pending until every started durable mutation settles. Prefer simply finishing the bounded local write before returning cancellation, or separate outward cancellation from the internal barrier. Source replacement/disposal must not allow a new coordinator on the same store to race the old writes. Reuse store ownership/serialization rather than add a speculative generation database.

Add real Dart completion-gate tests: cancel during checkpoint persistence, start a newer sweep, release completions adversarially, and prove durable progress never regresses. Include late tag upserts, disposal, persistence failures and resumed traversal. The earlier Python control-flow model was not a Dart execution.

**C4: missing tags versus explicit empty.** Current `NhentaiGalleryDetails` loses field presence by mapping absent/null `tags` to the same empty list as `tags: []`; malformed tag entries can abort all details. Preserve unknown/partial/complete source observations consistently with the corrected Pixiv DTO. Unknown does not erase saved tags; explicitly complete empty does. Keep usable metadata from a malformed subset and report partial coverage. Test DTO, shared mapping and actual saved-snapshot merge.

### Native feature integration

- Verify current native config/listing/search/details/tag envelopes and actual CDN GET plus decode using the application's coordinated transport. Historical HEAD probes and old WSL success do not prove current Android support. Keep evidence redacted and bounded.
- Preserve Gallery ID versus media_id, source Page numbers in the established 1-based key and 0-based positions, missing positions, source-supplied paths and validated numeric identity limits. Never compact later Page identities or guess original URLs.
- Share details and the Page manifest; do not refetch each Page. Use validated service/CDN hosts and exact returned paths. Do not silently repair duplicate extensions, introduce a proxy, or bypass an anti-bot challenge.
- Reuse Pixiv's completed shared Image View/Overview composition and generic Group/Page local targets. Normal local Bookmark targets Gallery; alternate targets Page. Download/share obey captured Page identity; Download All is bounded/cancellable and honest about missing Pages.
- Connect a durable, bounded tag store through the existing cache/storage organization. Visible tag lookups have priority. Catalogue warming is optional, resumable and nonblocking, with per-category progress, real response continuation and no assumption that requested page size was honored. Do not fetch the whole catalogue on startup or block reading for tag names.
- Test public/no-saved-profile browsing, restart/offline metadata, pagination, source errors, decoder failures, changed CDN configuration, tag checkpoint recovery, v10 import/export and Gallery/Page independence. Other engines/platform builds must remain intact.

A real external block is reported with the failing endpoint class/status and tested limits. Continue controlled implementation/tests and other stages; do not assert live support or full acceptance until the native read/decode gate is satisfied.

## D. Finish combined #160/#161/#162 acceptance

The combination must preserve one-viewport thumbnail layout caching and separate two-viewport page continuation, bounded layout filling, no automatic retry loops, navigation/app lifecycle guards, manual retry, and paginated-mode behavior. They are different budgets, not one setting.

Test ordinary PostGrid consumers, Favorites, local Bookmarks, cached Following feeds, Pools/Related and the newly connected Work/Gallery listings. If the native mixed-content listing needs an adapter, reuse the existing policy rather than create a site-specific unbounded page loop. Cached-only feeds must not accidentally fetch remote content; an inactive route cannot dispatch a delayed automatic request. Refresh and page-3 restoration retain their own invalidation rules.

Validate filtered/empty-with-continuation and nonempty-terminal Pixiv batches, concurrent fetch promotion, cancellation, rapid tab/privacy/account changes, short viewport fills and high-quality Realbooru thumbnail costs. Preserve all relevant tests when resolving common PostGrid/controller changes; do not take an older whole file over the merged behavior.

## Completion gate

Each stage gets issue-scoped commits and a handoff, but keep progressing to actual user-visible integration. Run changed package suites and production-path consumers during development. After integration run the complete regression on the exact combined candidate and fresh ordinary-main Android scenarios. Independent Sol High review must include the final shared viewer/picker/media/store behavior, not only the original foundation modules.
