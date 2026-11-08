# Bookmark outage, cache, performance and interaction remediation

## Evidence and scope

This is the requested implementation contract for the follow-up to #143/#158/#156. Read the [local-agent handoff](../handoffs/156-bookmark-review-remediation.md) for order and verification. Audited source: `0812367722defc59d36063ee9d4a631cf263b010` on `maintenance/156-shared-source-groups`; runtime candidate `2074d452a4d715ebd1b15ed9d1fea8446471a4d2`. All source paths below refer to that pinned tree unless the implementing agent records a newer one.

The user observed invisible occupied Danbooru cells, missing group covers, approximately 10-second initial Bookmark opening and 2-second mode switching, overly spacious/narrow pickers, unwanted leaf navigation and self rows, visible root Back, moving cover quadrants, unsuitable mode icons, unnecessarily shallow ancestor menus and profile-required Realbooru content. These are user reports, not measurements or device reproductions performed by this review.

Source inspection confirms the mechanisms identified below. It does not prove Danbooru was globally down, attribute the exact delays, or establish the exact visual animation mechanism. An attempted public robots.txt retrieval was unsuccessful in this environment; that is not outage evidence. No Flutter/Android suite was run here. The existing #156 approval and checks do not cover these new reproductions/fixes.

The latest requested picker and browser behavior supersedes the older navigable-leaf, current-group-row and always-clickable-title design. Keep the rest of the accepted hierarchy, direct-membership, source-safety and v10 transfer contract.

## N1. Source-policy failures produce invisible occupied cells

### Source-supported cause

`lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart` selects entries through `BookmarkProfileAvailability`, which largely classifies profile/source capability. Later `_buildItem()` watches `contentAccessForOriginProvider(post.origin)` and returns `SizedBox.shrink()` when `access?.config` is null. The sliver still reserves that entry's cell. The local-group cover renderer has an equivalent blank return.

In `lib/core/content/content_access_provider.dart`, `contentProfileAccessProvider` returns null while the effective policy is loading or failed. `contentEffectivePolicyProvider` awaits `blacklistTagsProvider`. `lib/core/blacklists/src/providers/blacklisted_tag_ref_notifier.dart` awaits site-specific blacklist data, even before applying an explicit replacement blacklist. Danbooru's `DanbooruBlacklistTagRepository` in `lib/boorus/danbooru/blacklist/src/providers/blacklisted_tags_notifier.dart` awaits `danbooruCurrentUserProvider` and server blacklist data.

Thus a remote-policy error can stop rendering before an image request or ErrorPlaceholder exists. `contentMediaFailuresProvider` cannot report a failure that never reached the image pipeline. This is a concrete failure path matching the report, not proof that every affected profile was waiting on that provider at the reported moment.

### Required behavior and implementation

Separate stored data, current access, policy readiness and media transport. A source timeout is not a missing local profile and does not invalidate the saved snapshot. Preserve local title/tag/membership actions independently of a successful website request. A failing source must not block healthy sources or the library shell.

Do not return an invisible widget for an occupied grid entry. Use the existing Kurumi loading/unavailable/error surfaces with preserved geometry and a localized explanation/retry action. Keep temporary failures distinguishable from policy rejection, ambiguous account, unsupported reader, invalid source, and a genuine empty group. Where the current design filters truly inaccessible records out, update the projection consistently and keep their saved count in the existing unavailable indicator; never leave holes or silently delete storage. Temporary transport failures should retain stable visible slots with explicit state rather than repeatedly reordering an open viewer.

Expose enough policy-loading/error state to the existing availability indicator; do not count ordinary in-progress loads as permanent failures. Avoid double counting one local Bookmark via several media renditions. Retrying a source-policy failure must retry the policy/access dependency, not only remount a tile. Retry only currently permitted visible work and preserve the captured actor.

For offline-capable cached presentation, retain a last successfully obtained effective policy scoped to the same exact profile/source and authorization generation in appropriate local protected storage. Apply current local filters immediately. Reuse that known policy during a transient refresh failure only when its provenance still matches; show stale/offline state where useful. No prior valid policy or a changed/deleted actor must fail closed with visible feedback. Do not substitute an empty blacklist on errors, use another profile's policy, or confuse 401/403 with a temporary 503. An explicit local replacement-policy configuration need not await irrelevant remote blacklist data; preserve its actual semantics in a focused test.

Required regressions: stalled policy, failed policy with/without valid local snapshot, policy refresh with retained previous data, local blacklist edits, credential changes, profile deletion, unrelated healthy source and explicit retry. Use fake request completion gates, not live downtime as the only reproduction.

## N2. Persistent media cache keys are not stable across sessions

### Confirmed source behavior

`lib/core/content/content_media_access.dart` builds a namespace from engine/site/profile plus `authEpoch` and `policyEpoch`, then prefixes `contentAccessEpochsProvider.sessionId`. `ContentAccessEpochs` creates that ID with `Uuid().v4()`. `lib/core/images/scoped_image_cache_manager.dart` hashes the namespace together with the URL into the delegate's file key. A new session therefore computes a different disk key for unchanged content. There is no automatic lookup of the old unscoped URL key in that wrapper.

Additionally, `ContentProfileAccess` is auto-disposed; a recreated notifier assigns a fresh policy epoch. Determine whether leaving/recreating the mode's consumers also changes the key within one process. This is a plausible extra source of misses, not a measured explanation for the user's two seconds.

Saved Post metadata and image bytes are different caches. `BookmarkLibraryService._load()` reads local records, repairs organization and builds indexes; the Bookmark timeline projects those snapshots. Neither requires fetching every Post from the source. Earlier thumbnails can still physically exist yet be unreachable through the new namespaced key. A group cover may also request a sample URL while only a thumbnail rendition was cached.

### Recommended correction

Keep transient authorization/cancellation keys for live requests. Give persistent media a separately stable, local, opaque cache identity whose lifetime matches the actual security boundary rather than a provider instance or process session. Reuse the existing managed cache, disk quota, leases and atomic writes.

A minimal conceptual cache descriptor has these fields; adapt an existing type rather than introducing a second access framework:

```text
PersistentMediaScope
  namespaceId: String          // opaque local random ID, stable across ordinary restarts
  engine: BooruType            // exact supported engine
  siteNamespace: String       // exact normalized installation, not a host suffix
  profileId?: String          // null only for explicitly permitted anonymous reads
  authGeneration: int         // durable non-secret revision, rotated on authorization changes
  schemaVersion: int          // cache descriptor format, not Bookmark backup version
```

It is a provenance/cache descriptor, never permission to read by itself. Check current authorization and visibility before opening cached bytes and again before publication. Current policy may re-evaluate already cached content or use a validated stable policy partition; it must not depend on observer creation order. Keep public and private namespaces separate. Do not put tokens, credential hashes, account headers or runtime controllers into filenames or export these local cache descriptors.

Rotate/revoke the durable generation on credential/account/source changes and deletion; reconcile profile import/replace/restore and all local mutation paths before access is enabled. A profile rename or an ordinary restart is not an authorization change. Concurrent providers must agree on the same generation. Deleted/recreated profiles must not accidentally reacquire earlier private bytes.

Do not fix this by merely removing `sessionId` while keeping runtime epoch numbers that can collide after restart. Do not blindly fall back from a private scoped miss to the old global URL cache. Reuse/promote legacy bytes only with adequate proven source/access provenance; otherwise retain the file under normal retention and accept a disclosed one-time miss. Do not wipe all media caches or saved data as a migration strategy. Do not weaken existing revocation tests to obtain a hit.

Test real on-disk reuse across full provider-container/process recreation, including offline decode, not just same-session memory hits. Cover both images and videos that consume the namespace, quota eviction, late writes after revocation, changed policy, account/source changes and unchanged actor after a mode remount.

## N3. A failed first cover candidate set starves group thumbnails

`BookmarkGroupBrowserPage._cards()` selects up to four Post previews and caches that choice. `selectBookmarkPreviews()` uses profile/capability eligibility, not current media/policy success. `_BookmarkGroupPreviewImage` returns an empty box for missing access and explicitly passes an empty loading placeholder. There is no candidate replacement when all early items belong to the failing source. `bookmarkGroupPreviewUrl()` normally chooses `sampleUrl`, so existing thumbnail-only cache entries may not satisfy the selected rendition.

Keep a bounded candidate window from the local metadata/indexes and the existing cover policy. Prefer already authorized cached renditions and the existing thumbnail resolver; avoid fetching a large sample/original solely for a tiny mosaic. Retain ordinary sort stability: do not reshuffle covers every frame or on a slow request. Only retire a candidate on a classified failure/denial, or use known local cache facts before loading.

On failure, try the next eligible candidate within an explicit budget. A starting implementation may inspect at most 12 local candidates per visible card with no more than four active image loads, sharing existing request/cache budgets. Treat these as tuning defaults to verify, not new global API limits. Do not scan/load every member or every descendant remotely to fill four cells. Source-level backoff/cooldown must prevent the same unavailable site causing a request storm across many cards. Preserve source-specific safety rules and record-level failure ownership.

If no allowed candidate succeeds, show the normal group surface/glyph, not an invisible card. Refresh candidates after explicit retry or relevant source/policy changes; do not cache temporary failure forever. A cover failure must never modify membership, order or timestamps.

## N4. Opening and mode-switch performance

### Known local work and likely amplification points

- `BookmarkLibraryNotifier.build()` awaits service load and UI-mode pruning. `BookmarkLibraryService._load()` decodes records, repairs memberships/dates and constructs shared indexes. First-use migration may add real local I/O. No per-Post network refresh occurs in this load path.
- `BookmarkGroupViewPreferences._persist()` awaits misc-store writing before publishing the new mode.
- The browser keys `BookmarkScrollView` by `(groupId, mode)`, so switching recreates the raw Post controller, projects records and reruns filtering. New consumers may also recreate access/cache scope instances.
- `_unavailableCounts()` invokes `selectBookmarkGridEntries()` again merely to count failures; inspect repeated filtering/sorting under media-failure notifications.
- Availability currently loops saved items and resolves profiles for each. Group preview selection is already scoped in several cases; preserve its existing optimization rather than replacing it wholesale.

None of these source observations assigns the reported 10/2 seconds to a single cause.

### Measurement and fixes

Use the existing `performanceRecorder` operations (`bookmarkLibraryLoad`, `bookmarkFetch`, `bookmarkSelect`, `bookmarkProject`) and add narrow spans/counters for migration, decode/index build, mode-store write, query projection, policy wait, first frame and first decoded thumbnail. Compare first upgrade, subsequent cold start, warm first open and repeated warm toggles on the same known large dataset. Record UI-thread work and request/cache counts; do not compare debug and release timings as equivalent evidence.

The acceptance contract is immediate local navigation/shell feedback independent of website completion. A warm toggle must not need remote Post/Group metadata, discard valid decoded images, or repeatedly open/repair the database. Use bounded cached query/projection results keyed by library revision, group, mode, query, source filter, sort/shuffle and relevant availability revision. Reuse immutable saved objects and indexes. Do not cache every group's full subtree permanently or retain hidden live grids indefinitely merely to avoid recomputation.

Count unavailable results from an unsorted/cached selected projection rather than resorting all entries for every failure event. Resolve repeated source/profile combinations once per relevant revision where safe. Make the visual mode change independent of slow preference I/O, either with a local immediate presentation state and serialized persisted update or a correctly versioned optimistic write with rollback/error feedback. Do not let a late failed write undo a newer choice.

Only move measured CPU-heavy pure computation off the UI isolate when simpler indexing/reuse is insufficient; include revision/cancellation guards. Preserve scope-specific membership dates, deduplication by local ID, selected record identity and query/scroll state. Demonstrate before/after measurements and structural request-count tests; do not add brittle millisecond budgets to ordinary unit tests.

## N5. Children-only groups must not show a fake empty timeline

`BookmarkGroupBrowserPage.build()` currently adds a divider whenever Structure has child groups, and appends No bookmarks whenever the direct set is empty. Both conditions are visible in the source.

Use unfiltered saved membership facts, not media availability, for structural emptiness:

| State | Result |
| --- | --- |
| Structure: children, no direct saved records | Child cards only; no trailing divider, empty timeline message or search controls. |
| Structure: children and direct saved records | Child cards, compact separator, existing searchable direct timeline. |
| Structure: no children and no direct records | Normal genuinely empty-group state. |
| Direct records exist but query filters to zero | Keep search/filter controls and a search-empty state. |
| Direct records exist but source access/media fails | Preserve unavailable/error feedback; never report that the group contains no saved records. |
| All Bookmarks | Hide local child cards; render/search the deduplicated subtree. A genuinely empty subtree may show its normal empty state. |

## N6. Compact, thumb-friendly shared pickers

### Confirmed geometry and behavior

`BookmarkPickerSplitRow` enforces 60dp minimum height, reserves 80dp at the trailing edge and centers the chevron there. `BookmarkBatchDialog` adds 16dp horizontal padding. `KurumiDialog` caps its surface at 80% of screen width regardless of the requested 420dp width. At 360dp, that yields a 288dp surface and 256dp inner row before its own row padding. The anchored presenter additionally wraps its 280dp maximum content in 8dp padding. These nested constraints explain narrow content and an inset chevron; actual rendered heights still need normal-device verification.

Every group currently gets `onOpen`, including leaves. The entered current group is rendered again. The Home Back row is always built and can receive the root dismissal callback. These are older design decisions now explicitly changed by the user.

### New contract

1. Share geometry and behavior across anchored, modal, context and batch Bookmark pickers. Keep Kurumi surfaces. Preserve the distinction between toggle, add-only, remove-only and destination selection.
2. Use approximately 48dp minimum interactive row height at ordinary text scale, centered content, no extra blank spacer rows. Let rows grow when needed for enlarged text; do not shrink body text to force a fixed height. Maintain at least the existing accessible touch-target precedent.
3. Keep the navigation hit region roughly 80dp wide and full height for parent groups. Align its chevron at the actual trailing edge with only normal 8-12dp glyph inset, rather than centering it. The rest of the row remains one full-height direct-action target. No overlapping gesture detectors or dead lower strip. Mirror directionally for RTL.
4. Make the list flush with its surface, with one intentional text/icon inset, not stacked shell/list/item margins. On phones use about 12dp outer safe-screen gutters and an appropriate maximum width (for example 420dp) on larger displays. For anchors, respect actual available horizontal/vertical space, keyboard and the invoking control. Do not change every app dialog's width globally: add a backward-compatible opt-in constraint/inset to Kurumi if its hard 0.8 cap prevents this caller's layout. Test other callers' defaults unchanged.
5. Only groups with actual children have a navigation action. A leaf has no chevron and no reserved inactive 80dp column; its row is directly selectable. Apply the same rule to Recent. An intermediate nonselectable ancestor may still expose navigation when it leads to valid targets.
6. Remove the repeated current-group/Save here/Remove here row. Parent groups remain direct targets in their parent's list; Back then a body tap selects them. Do not invent another duplicated action or hidden gesture. Subgroup creation remains available at a navigable current group and in normal group management; do not keep empty leaf navigation just for creation.
7. At Home hide the visible Back icon/path/dismiss row entirely. Preserve Add Group on the trailing side where offered. With no navigation/creation controls, omit the empty header/divider too. In subgroups retain Back/path leading and Add Group trailing. Native Back/Escape still goes up one level, then dismisses at root. Child dialogs/IME retain their existing ownership; do not pop the underlying viewer or add custom swipes.
8. Direct membership checkmarks remain direct, not inherited from descendants. Preserve pinned Recent, successful-action dismissal, frozen targets, small-height scrolling, input focus, creation cancellation and live deletion of a target.

Primary paths: `bookmark_folder_picker_contents.dart`, `bookmark_group_picker.dart`, `bookmark_batch_dialog.dart`, `bookmark_multi_selection.dart`, `bookmark_group_destination_picker.dart`, and the related Kurumi `dialog.dart`/`popup_menu.dart` components. Inspect all shared callers rather than fixing only one screenshot.

## N7. The four cover tiles must be a fixed mosaic

`BookmarkGroupPreviewGrid` currently creates a nested `GridView.builder` with `NeverScrollableScrollPhysics` for four decorative images. That is still a ScrollView; no `primary: false` or owned controller is set. The outer card itself contains no translation animation. Nested scrolling/primary-controller/overscroll behavior is a strong source-level candidate for the reported edge movement, but the exact animated path has not been observed here.

Reproduce with four deterministic decoded images so network fade/replacement is excluded. Measure each image rectangle relative to the clipped card during drag, fling, reversal and both overscroll edges. Repeat with animation loading enabled and disabled to distinguish layout motion from image presentation.

Prefer a fixed four-cell layout (two Rows inside a Column, or a constrained Stack), not an inner scrolling viewport. Keep the present 2x2 spacing, clip and image fitting, no inner Hero or entry slide. Only the outer browser scrolls. Preserve legitimate image/GIF behavior and avoid a global disable-animations workaround. If the controlled geometry test disproves the nested-scroll mechanism, diagnose the actual image transition/key reuse and retain that evidence rather than asserting a false cause.

Framework reference: https://api.flutter.dev/flutter/widgets/GridView-class.html describes GridView as a ScrollView and its primary/controller/physics and PageStorage behavior. Use the pinned Flutter version for runtime verification, not a documentation-version assumption.

## N8. Ancestor title depth and mode icons

Define Home as depth 0, a direct child group as depth 1, and its subgroup as depth 2. Only depth >= 2 exposes the clickable title/ancestor menu. At Home/depth 1 render an ordinary fitted title with no dropdown arrow, hidden focus target or popup semantics; the normal Back control already supplies the useful navigation. Derive depth from the current parent chain, not how the user arrived or the number of children.

Keep mode switching in the Header, never an extra row. Supply localized action tooltips (for example Switch to All bookmarks) while making the current mode accessible. Keep All Bookmarks terminology: this view includes saved remote Group references as individual items and does not recursively fetch their Pages.

Two editable [SVG icon families](bookmark-view-icons/README.md) accompany this contract. A depicts the real screen distinction (folder section plus direct items versus one uniform grid); B depicts nested grouping versus a content stack. A is the recommendation, not an approved production selection. Keep them out of runtime until the user chooses. Correctness work is not blocked by that choice. Penpot import/publishing has not been performed by this delivery.

## N9. Realbooru without a profile

`AnonymousSourcePolicy._sources` contains no Realbooru endpoint. Its API predicate currently handles Danbooru, Gelbooru V2 and Moebooru only. The missing-profile outcome is therefore explainable without any outage: a working profile-specific reader is not automatically an allowed anonymous reader.

Realbooru's own API help documents `/index.php?page=dapi&s=post&q=index`, `limit`, `pid`, `tags` and `id`: https://realbooru.com/index.php?page=help&topic=dapi. It was readable during this review through the web tool, whose result was cached. That establishes documentation, not a current anonymous media GET/decode pass or an exhaustive CDN allowlist.

Confirm the actual engine/site declaration used by the existing Realbooru integration and its parser/client. Do not infer the engine from the URL name or enable an entire engine for arbitrary installations. Add only verified built-in HTTPS source roots and actual required API/media destinations. Test raw anonymous GET responses, page indexing, relevant media variants and real Android decode, including redirects. Preserve bodyless reads, header/cookie/proxy isolation, no account capabilities, and the existing URL/path/query guards. A HEAD success or help page alone is insufficient. Do not synthesize a persistent profile or silently borrow another account.

Keep cross-host/scheme aliases explicit rather than changing content identity. If real media requires additional hosts, document exact evidence and add narrow tests. If a challenge or unavailable site blocks validation, report the exact limitation; do not bypass it or display unsupported access as ready. Improve the reason label where the current Missing profile text conflates unsupported anonymous access with actual authentication requirements. Keep inaccessible saved data exportable.

## Earlier review findings: retain and reproduce

These findings were traced on the same runtime but were not reproduced by this chat in Flutter. They remain part of the requested remediation; prove each failing production path before changing it, or document a counterexample.

### R1. Public Group selection can resolve another saved actor

`OriginAwarePostRepository` intentionally gives public member Posts no profile hint. `PostActionSnapshot` independently resolves their origin against saved profiles; `PostSelectionActions`, `DefaultMultiSelectionActions` and `postActionDefinitions` can then build explicit account-bound services without carrying the original public `ContentAccessKey`. The leaf download check only sees the now-private auth. This is an account-binding risk, not a demonstrated credential leak to an unrelated host.

Use the captured source actor at both presentation and execution. Do not resolve an already bound public/revoked gallery through current compatible profiles. Propagate current checks across permission, extraction and scheduling awaits. Test a public Pool with another same-site profile present, including a non-separately-bookmarked member, bulk selection and a profile added after opening. Verify no account favorite lookup/write or private download provider is invoked.

### R2. Deleted current group falls back repeatedly

`BookmarkGroupBrowserPage._currentId()` derives a surviving ancestor while `_requestedId` can remain the deleted ID; build replaces `_lastPath` with that ancestor's ancestors. Later rebuilds can repeat the fallback one level higher. Normalize the requested ID and legacy-route flag once in a controlled navigation transition, not with setState during build. Reuse the picker navigation's stable fallback pattern. Test deletion at depth 3, repeated library/viewport rebuilds, external deletion and Undo.

### R3. Paginated checkpoints lose the saved page

`PoolGalleryCheckpoint` activates restoration only for offset > 0 and conditionally fetches more based on scroll extent. It does not explicitly restore page 3 at offset 0, or page 3 with an offset that already fits page 1. `GroupPostScope` creates a controller at the initial page.

Separate paginated and infinite restoration. In paginated mode load the saved page through the bounded indexed source, then restore/clamp its offset; in infinite mode retain bounded restoration of the visited extent. Test real eviction/remount with retained PageStorage, offset zero and positive offsets, changed page size, shortened manifests and two occurrences of the same Group. Do not crawl all prior pages to restore an indexed page.

### R4. Refresh leaves Group metadata stale

`GroupPostPager.refresh()` invalidates the adapter envelope and resolved members, but the completed `groupDetailsProvider` observes the same source instance and is not automatically invalidated. The new manifest/posts can coexist with old title/description/category/date. `PoolDetailPage.prepareSource` can offer its old initial envelope again during rebuild.

Coordinate refresh for the exact reference/access: invalidate once, refresh metadata and members using shared envelope work, reject superseded results and prevent stale seed reuse. Preserve captured actor, occurrence state and current-page behavior. Test the actual ContentGroupPage and Header, not only GroupPostScope: change description/title/count and manifest, refresh on a nonfirst page and assert a consistent new generation without duplicate requests.

## Boundaries and acceptance

This is targeted remediation, not a new content hierarchy, migration rewrite, unrestricted offline permission system or global timeline redesign. Preserve source identity uncertainty, local Bookmark IDs, timestamps, v10 backups, direct membership/Undo, additive Favorites Sync, repeated source-member occurrences and existing prefetch budgets.

Complete the handoff's automated/device matrix and an independent final Sol High review before calling the candidate ready. Keep confidence distinctions in the report: user-observed symptom, source-confirmed mechanism, reproduced regression, implemented fix, and verified result. Do not claim actual Danbooru outage, exact performance attribution, restored old cache provenance or Penpot publication without evidence.
