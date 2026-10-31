# Issue #68 — Rolling Search Series handoff

Prepared 2026-10-31. Branch: `feature/group-neighboring-series`.

## Candidate and scope

- Reviewed starting local/origin HEAD: `8cdacc39e384f75d5f6d20a01451d3466912f48c`.
- Fresh local/origin develop and merge base: `de5928283aa39f0d67d6a834e42d4fa5e9369b86`. No further rebase was needed.
- Final implementation/test commit: `19880c6bb3aec8b6f6322ed87f6e17b5d34c6bed` (`feat: extend Search Series through rolling result windows (#68)`). All automated checks below verify this exact tree. The handoff child changes documentation only.
- Implemented scope is prepared for user review. Related Posts grouping is a separate follow-up, excluded from this change; it is no longer an unresolved design dependency for these Search corrections.

This supersedes the strict-adjacency and loaded-run-count portions of [the previous handoff](accepted-review-followup-20261031-68.md). Issue #68 and both design documents now reflect the accepted rolling-window scope. Preserve the rest of the earlier Bookmark/reference/cover implementation.

## Behavior and critical review

`groupNeighboringSeries` uses five **filtered raw result positions** after each matching member. Every further match extends the window. The card stays at its first member; unrelated intervening Posts remain independent entries in their original relative order. Every raw index appears exactly once. Overlapping Series are deterministic: the earliest unclaimed post starts a group, the candidate reaching the most unclaimed matching members wins, and the lowest Series ID breaks ties. Already claimed positions still count toward the five-position distance. Every grouped member has the same source/profile/auth scope and confirmed Series identity.

Entries retain an immutable list of original indices, rather than deriving a consecutive range from first index plus member count. Built display entries are frozen by their first raw index. Existing Series cards can extend into unbuilt results across page boundaries without changing their key, first cover or position; they cannot consume another built tile. Deferred metadata may group unseen entries only. Query/profile/controller replacement, refresh and changed filtered prefixes discard obsolete projection state. Scroll tags map **all** collapsed raw member indices to the card's geometry, and safely remove only registrations still owned by that card. Selection expands the original filtered Posts and uses raw indices; long press selects the first actual member, not a synthetic Series post.

Search cards use the first grouped Post and display `Series · X/total` when the displayed group's count differs from the authoritative Series total; equal counts display `Series · total`. Each displayed group has its own X. Pool/reference cards omit the optional displayed count and retain their existing labels. Tapping still opens the full source-scoped Series. Explicit `pool:`/`series:` searches, direct collection views and selection stay ungrouped. Individual Bookmarks remain separate, and saved Pool/Series references, quality variants, source restrictions, persistence and backups are unchanged.

A collapsed, underfilled infinite viewport may request at most **three additional ordinary pages per cycle** through the existing `PostGridController`. Rebuilds and automatic completion do not renew that budget. Manual page advances and fresh query/refresh cycles allow another bounded fill. The completion records its final page before releasing its automatic latch; this prevents a coalesced controller notification from being mistaken for a manual advance. Manual Load More remains present. Failure/cancellation stops automatic fill; existing error handling, raw items, page rollback, retry and exhaustion remain owned by the controller. Paginated mode, selection and explicit collection searches do not trigger this fill.

Reviewed the complete new diff against `8cdacc39`, its surrounding Search/controller/grid/selection code, the existing Danbooru capability, scroll-to-index registration ownership, and the previous full branch handoff. No persistence/schema, collection identity, Related UI, media-quality policy or unrelated branch changes were introduced.

## Metadata-loading investigation

Initial Search page delivery already awaited `SearchSeriesIndex.load`; this remains intentional in this correction. One admission covers at most 40 Posts, coalesces pending IDs, uses one bounded Danbooru Pool lookup, has a ten-second timeout, and retains at most 512 source/account-scoped cache entries. There is no full-Series crawl or member-media fetch. Later viewport admissions retain the existing bounded window scheme.

The controlled production test holds the metadata response: the Search controller remains refreshing with no delivered Posts until the response or timeout. After advancing the controlled clock past the timeout, raw Posts appear. Releasing the response afterward does not collapse built tiles or change their bounds; only bounded retry/admission work is allowed. Thus the wait can add up to ten seconds of metadata latency to **each page** before that page is delivered; an underfilled cycle can await this independently on its additional pages. The original post request has its own network latency/timeout, outside this ten-second metadata bound.

This is a verified latency/geometry tradeoff, not a measured live performance improvement. Removing the await would require accepting permanently ungrouped built Posts or introducing stable placeholders; neither was added. No uncontrolled requests, new background synchronization or visible late collapse was introduced.

## Automated verification

All commands used FVM in the existing worktree. Default physical-core concurrency was six.

1. **Focused regressions: PASS, 65 tests** (`focused-v8.log`):

   ```sh
   fvm flutter test --no-pub --concurrency=6 \
     test/application/pool_bookmark_flow_test.dart \
     test/core/posts/listing/neighboring_series_test.dart \
     test/core/posts/listing/search_series_index_test.dart \
     test/core/bookmarks/pool_bookmark_persistence_test.dart \
     test/core/bookmarks/pool_bookmark_source_policy_test.dart \
     test/core/bookmarks/pool_bookmark_refresh_failure_test.dart
   ```

   Coverage includes fifth/sixth-position boundaries and repeated window extension; overlapping Series and seeded raw-index preservation; frozen noncontiguous members; cross-page continuation and independent holes; partial/equal count labels; all-member scroll aliases and raw selection; three-page budget exhaustion and actual manual button continuation; server failure, cancellation and explicit retry; query replacement while a page is held; paginated-mode suppression; initial metadata timeout/late completion; 320dp at 1x/2x text; existing cover quality changes, legacy references, source isolation, persistence and backup round trips. The existing 90-Post production Search scroll/admission test also passes.

2. **Scoped analysis: PASS, zero errors, zero warnings, 20 informational findings**:

   ```sh
   fvm flutter analyze --no-pub --no-fatal-infos \
     lib/core/posts/listing/src/types/neighboring_series.dart \
     lib/core/posts/listing/src/widgets/post_grid.dart \
     lib/core/posts/pools/pool_grid_item.dart \
     lib/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart \
     test/core/posts/listing/neighboring_series_test.dart \
     test/application/pool_bookmark_flow_test.dart
   ```

   The analyzed tracked patch hash was checked against committed `19880c6bb`; they match. Informational findings include existing import/style/default-value diagnostics and are not described as lint-clean.

3. **Complete local regression: PASS, 599.4 seconds**, clean committed `19880c6bb` before and after:

   ```sh
   ./scripts/run_regression_tests.sh
   ```

   5,680 application tests, 1,608 package/CLI tests, both repository shell suites and 72 Python tests passed. Two existing go_router skips remain. This is a complete pass on the final modified runtime/test candidate, not a pass reused from the reviewed starting branch.

4. **Android compilation: PASS**, Gradle task 31.8 seconds:

   ```sh
   fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub
   ```

   Build began before the implementation commit was created; hashes of every changed file were verified identical to `19880c6bb`. The frozen APK and installed APK both have SHA-256 `e01974a2827431778e86897081fcd5d54bce8164bc431365faec5436b14dde19`.

Changed Dart files were formatted with `fvm dart format`; `git diff --check` passed. No generated runtime inputs changed and `gen.sh` was not needed. Existing native-hook “File modified during build” notices, Android toolchain notices and occasional Dart VM callback/finalizer diagnostics remain in the passing logs; they are distinct from command exit status. Earlier failed/diagnostic test iterations are retained and superseded by the final focused/full passes.

## Actual Android acceptance and limits

Device `emulator-5554` was exclusively leased and controlled using Maestro MCP. No app-data reset, account mutation, recipient send or bookmark/library fixture creation was used.

- Live Danbooru `malberrybush`: 349 Results, 60 loaded Posts, and `Original - Kinktober 2026 (Malberrybush)` displayed as `Series · 29`.
- Tapping that card opened the full Pool with **29 posts** and normal Ordered/Latest/Oldest controls. Back returned to the same Search card.
- Long press entered ungrouped selection with **1 item selected**; Select All showed **60 items selected**. Closing selection restored the Series card. Scrolling down and back restored the visible card.
- Live explicit `pool:32092` showed **29 posts** with no Series card/regrouping.
- The displayed media remained placeholders during this session. These checks prove live metadata/counts/navigation/selection and layout interaction, **not decoded thumbnail pixels, image resolution or cover request counts**. Controlled production tests verify that the card uses the first grouped Post, and existing quality/persistence/backup regressions pass.

The original Safebooru (Danbooru) profile was restored and verified selected; the original APK was restored without clearing data and its installed hash was verified. Original APK SHA-256: `b2f7e6915803859e0348ae77780dc0c5d748a1e87d028f902ce968b8e8a9f9bb` (original source commit unknown). No listing/quality/language settings were changed. Ordinary QA Search history may remain; existing history was not cleared. The device lease was released after restoration.

## Remaining manual acceptance and delivery

Review the rolling-window grouping/count UX with real readable thumbnails once live image access works. Check partial groups against their full Series and confirm the first-member cover visually. Very long live sessions, image-resolution comparisons and physical-device frame timing were not measured; raw preservation, bounded work, delayed responses, scroll anchors and failure behavior have controlled regression coverage. Related Posts grouping is intentionally a separate follow-up.

The branch is committed locally and Issue #68 remains open for review. No new code push, PR, merge, develop integration, issue closure or branch deletion was performed. A later rebase or combined develop runtime/test candidate needs a new complete regression pass.

Durable raw artifacts are under the primary checkout's ignored `.worktrees/_artifacts/68-rolling-series-20261031/`: qualification/analysis correspondence JSON, command logs, source hashes, frozen APK, installed/restoration hashes, device observations, screenshots and recovery notes. Important development artifacts were not stored in `/tmp`.
