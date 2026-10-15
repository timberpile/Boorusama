# 0035 – Unify pinned searches and following feeds as Topics

Priority: High
Affected feature: Following, pinned searches, feed caches, subscriptions, imports/backups

## Problem

The app maintains independent pinned searches and separately managed feeds
whose hidden sources duplicate queries and refresh state. Users must manage the
same kind of search twice. Existing feed caches are cleared when membership
changes, and the feed model assumes a single profile.

## Expected behavior

- Replace the two navigation destinations with **Following**. A **Topic** is a
  pinned search: opening it uses the normal search and pagination. Preserve the
  current pinned-search/collection UI, folder tree, card actions and selection.
- Topics and folders share one editable organization. A folder can be marked
  **Enable feed** at creation or later. Only enabled folders expose **Open Feed**.
  Its posts combine the folder's topics and descendants, newest-first.
- A feed is identified by its folder; avoid duplicate feed management and
  duplicate refresh work. Feed options include an adjustable retained-post limit
  (default **1000**), persisted per folder. Retain the existing Hive persistence
  mechanism for the first delivery; measure before any SQLite migration.
- An enabled feed acquires a permanent materialized snapshot cache and
  initialization state. Never discard it solely due to inactivity or a folder
  rename. Allow explicit cache removal with measured size in cache settings.
  Keep the cache when feed mode is switched off, unless explicitly cleared.
  Add/remove/edit/move topics should incrementally reconcile affected caches,
  respecting overlapping post matches; no unconditional full rebuild.
- Topic refresh and auto-refresh reuse the existing adaptive scheduler, API
  coordinator, cooldowns, power/network guards and in-flight coalescing.
  Add optional per-topic Auto-update controls including bulk selection; preserve
  existing disabled settings in migration. Do not add a folder scheduler.
  Initialize newly enabled feeds using bounded existing queues, prioritizing
  uninitialized/oldest checked topics and without resetting existing NEW state.
- Support mixed Booru profiles: resolve query execution and post actions using
  each source's origin/profile; use site/instance + post ID for deduplication,
  not unqualified numeric IDs.
- Improve refresh through verified per-site result caps, safe server-side
  delta filters where supported, and approximate new-post counts. Do not
  assume a query that returns posts is necessarily chronologically trackable.
  Retain safe bounded fallback on unsupported or uncertain endpoints.
- Opening a feed marks all contained topics read (first iteration).
  Keep existing history pagination; investigate its reliability separately.
  Exact duplicate queries may remain independent topic records for now;
  cross-folder shared references are a later optimization.
- Migrate existing pins, nested folders, feeds, subscriptions, cache contents
  where safe, and backups without silently deleting personal data.

## Acceptance criteria

- [x] Following replaces both old navigation entries without changing ordinary
      pinned-search interaction patterns.
- [x] Create/edit folder toggles feed mode; cache limit defaults to 1000 and is
      configurable/persistent; feed mode and cache lifetime are independent.
- [x] Opening a Topic uses its normal search; enabled folders show Open Feed;
      all descendants are included with post-origin-aware deduplication.
- [x] Feed caches initialize progressively, persist across restarts, update
      incrementally and can be cleared from cache settings.
- [x] Query edits, deletions, movements, overlaps, failed refreshes and duplicate
      definitions never corrupt other valid cached posts.
- [x] Existing adaptive, bounded, origin-aware request coordination is preserved;
      site-specific delta/cap capabilities are verified with tests.
- [x] Per-topic auto-update and bulk update function with safe migration of
      existing preferences; approximate NEW indicators are correct or bounded.
- [x] Backups/imports/restore and profile/site change migrations preserve data.
- [x] Narrow-width, enlarged text, keyboard and action tests pass.
- [x] Scope-appropriate tests pass; complete app/package/tooling suite passes on
      the final combined candidate before any approved develop integration.

## Constraints and dependencies

- Follow [AGENTS.md](../../../AGENTS.md),
  [work queue](../README.md), and
  [subsystem documentation](../../following_topics.md).
- Preserve existing Kurumi UI and localized strings. No new UI mockup is
  required to implement the already agreed behavior.
- SQLite cache migration and more extensive feed history pagination are
  explicitly **out of scope** until measurement / separate work.
- No PR or develop integration without a separate request.

## Claim and progress

- Continued locally on 2026-10-15 by Codex, from handoff commit
  `c8038a75f86ecbe105716fb820aff4caed8ce4d2` (confirmed against fetched origin).
- Branch: `feature/0035-unified-following-topics`.
- Worktree: `/home/timber/code/Boorusama/.worktrees/0035-unified-following-topics`.
- Original base remains `b95aafa47214b1a24b285d5a1fc24c8dbcad9975`.
  Existing commits were preserved. No merge, PR or publication is authorized.
- Formatted every branch-modified Dart file, initialized pinned FVM dependencies
  and generated missing runtime/localization outputs. Fixed seven inherited
  compilation errors. The first complete affected run passed 1128 tests and
  failed 17; later fixes and current verification are recorded below.
- Unified desktop/mobile navigation and artist/tag Follow controls; folder
  settings, independent Topics and per-topic/bulk Auto-update use existing UI.
- Replaced unsafe newest-first bounded deltas with validated ascending Donmai
  keysets. Larger backlogs resume from the persisted prefix; full initial feed
  snapshots cannot jump it. Other sites retain bounded snapshots. Documented
  official caps and constrained-query/custom-instance fallbacks.
- Preserved initialized sources and cached matches during membership updates;
  fixed cancellation recovery, cooldown/power guards, disabled-feed behavior,
  atomic cache writes and mixed-profile cache invalidation.
- Fixed numeric tie sorting, displayed-grid deduplication, per-origin selection,
  grouped downloads and bookmark source links. Added mixed-site same-ID tests.
- Aligned import review, custom export selection and execution with independent
  Topic identities. Folder copies retain their own Topics. Migration and import
  rollback preserve Auto-update and unread estimates. Legacy operations cannot
  delete visible Topics or silently overwrite modern folder feeds.
- Cache settings explicitly identify the serialized size as an estimate.
  Benchmarks now measure 1000/2000 snapshots, aggregate Hive writes/flushes and
  reopening/decoding, excluding a warm-up from five measured samples.
- Current implementation details and documented API evidence:
  [Following and Topics](../../following_topics.md#unified-following-work-item-0035).

## Verification

Local implementation and qualification completed on 2026-10-15. The checked
state was handoff HEAD `c8038a75f86ecbe105716fb820aff4caed8ce4d2` plus the final
implementation/test changes captured by this completion commit. Only
report/documentation updates followed the complete pass; runtime, dependencies,
generated outputs and executed tests stayed unchanged.

- `fvm flutter pub get`; `fvm dart pub get` in `packages/boorusama_cli`;
  `./gen.sh` for missing generated outputs and `./gen.sh i18n` for final strings:
  passed, including translation validation.
- `fvm dart format` on every branch-modified Dart file and the new tests:
  completed; `git diff --check` passed.
- Static analysis on all changed tracked Dart files:
  `git diff --name-only -z -- '*.dart' | xargs -0 fvm flutter analyze --no-pub --no-fatal-infos`.
  The newly added dialog test was also analyzed explicitly. Final affected-file
  analysis covered the replacement rollback and controlled-power fixtures.
  All analysis commands passed with **zero errors and zero warnings**;
  informational style lints remain (58 in the broad analysis, six in the last
  targeted analysis).
- `./scripts/run_regression_tests.sh`: **passed**, concurrency **6** from
  `python3 scripts/physical_core_count.py`. All 16 required gates completed:
  **3356 application tests**, **934 tests across all 12 package/CLI suites**,
  both shell policy/release-script suites, and **61 Python tooling tests**.
  **4290 Flutter/Dart tests passed; zero failures and zero reported skips**.
  Packages: booru_clients, boorusama_cli, cache_manager, coreutils, dtext,
  extended_image, filename_generator, flutter_sqlite3_migration, foundation,
  i18n_cli, kurumi and retriable.
- Direct subscription, backup, bookmark and artist Follow suites were executed
  during implementation. Regressions cover a 1500-post truncated delta across
  refresh/service restarts; initial snapshots with pending deltas; later-page
  failure/order rejection; cancellation and power/cooldown recovery; overlap,
  nested mixed-site same-ID caches and grid selection; profile invalidation;
  clone preferences; backup ID reuse; import previews/copies and rollback after
  legacy ownership replacement; shared bookmark origin links.
- Widget checks include folder settings at **320px / 2x text**, with and without
  **280px keyboard insets**, changing retention to 2000 and saving. Existing
  narrow/enlarged Info, navigation, folder, edit/move/selection and search-action
  tests also passed. Initializing and opening feed caches preserve read state.
- Earlier runs failed on inherited compilation errors, stale UI/duplicate-copy
  expectations and fixture issues; they were corrected. One full app attempt
  stopped at 3354 passes / one stale folder-delete label expectation. Interrupted
  runs were not counted as passes. The complete final gate above supersedes them.

### Hive benchmark

`fvm flutter test --no-pub --concurrency=1 benchmark/feed_cache_profile_uuid_performance_test.dart --reporter expanded`
passed both workloads after the regression and analysis processes had finished.
Each workload excludes one warm-up and records five measurements on this Linux
host. Times are milliseconds; sizes are serialized JSON, not physical disk use.

| Snapshots | JSON bytes | Decode median | Hive write + flush median (range) | Reopen + decode median (range) |
| ---: | ---: | ---: | ---: | ---: |
| 1000 | 791569 | 13.219 | 18.064 (15.270–31.276) | 55.547 (40.889–76.836) |
| 2000 | 1589569 | 26.516 | 33.466 (27.742–46.209) | 121.921 (91.535–154.421) |

Reopening clears Hive's in-memory box state; it does not clear the operating
system's file cache. These synthetic JIT/Linux results are diagnostics, not
Android release-mode latency guarantees or a before/after speedup claim. Hive
remains in use; no SQLite migration or automatic eviction was introduced.

### Limits and integration boundary

No emulator, phone, authenticated live API, upgrade install, CI or remote
acceptance has been exercised in this continuation. Narrow-width, enlarged-text
and keyboard checks use local widget tests. A future develop integration needs
verification of its final combined candidate and explicit authorization.

Known conservative behavior: optimized deltas are enabled only for the verified
Donmai root endpoints and simple tag/rating queries. Other engines and constrained
queries retain bounded snapshots. Legacy caches without proven origins or
provenance keep generic/conservative handling. Legacy feed definition conflicts
with an existing folder UUID require an explicit copy through import; they do
not overwrite its visible Topics. Broader history reliability remains out of
scope. Full qualification here covers the feature branch; combining it with a
later develop candidate requires the separate complete integration gate.


## Follow-up: Danbooru term allowance and wording (2026-10-15)

Reopened after local completion commit `1bf446168` to address the user's
`zenless_zone_zero 1girl` refresh failure and terminology review, on the same
branch/worktree. Existing completion evidence above applies to that earlier
candidate; the checks below qualify this follow-up separately.

### Refresh correction

- Reproduced the failure in a focused service regression before the fix: the
  second refresh added `order:id_asc`, turning the valid two-tag query into three
  counted terms. Danbooru's
  [PostQuery implementation](https://github.com/danbooru/danbooru/blob/master/app/logical/post_query.rb)
  exempts `id:` and `rating:`, but counts `order:` against the account allowance.
- Reserve room for ascending ordering within the basic two-term allowance.
  Queries with two or more counted terms retain the original bounded snapshot
  query; do not assume a higher account tier. Replacing an already requested
  descending ID ordering adds no counted term. Constrained/custom-instance
  fallback and ascending checkpoint validation remain intact.
- Snapshot fallback retains the existing bounded coverage and lower-bound NEW
  estimates; it does not promise resumable backlog coverage. Safe ascending
  catch-up remains enabled for eligible queries. No descending delta is used to
  advance a checkpoint past unfetched posts.
- Regression coverage exercises the exact reported query through baseline and
  subsequent refresh, NEW counts, ratings, negated tags, wildcards, repeated
  terms and pre-existing ordering. Existing 1500-post restart/catch-up and
  failure/checkpoint tests remain part of verification.

### Wording audit

Searched case-insensitively for pin/feed occurrences across application code and
translation files and traced the topic entry points and their consumers.

- Search-result pin action becomes a shared accessible Follow/Following pill,
  matching artist controls. Following opens existing topic management. Topic
  navigation and backup icons use the same RSS symbol as other follow controls.
- New-topic dialog: **Follow Topic**, submit **Follow**. Bulk action:
  **Follow Topics**. Removal: **Unfollow**. Success, preview failures, refresh
  scope, folder deletion and legacy member descriptions use topic wording.
- Folder context actions: **Refresh** and **Settings**. The tag context menu
  uses reactive **Follow/Following**, replacing **Add to feed**.
- Retained **Open Feed**, **Enable feed**, cache statistics, retention, freshness
  and legacy feed import names: these describe the folder's combined posts or
  identify the older backup format. Site-native Danbooru/Pixiv feeds are separate
  features and retain their names.
- Retained app-lock PIN, window pinning and pinned forum threads. Persisted Hive
  names, routes, backup identifiers, localization keys and internal model/API
  names remain compatible; they are not user-facing pin actions.
- Updated English and German topic text; other locales inherit these fallback
  keys as before. The changed follow-action labels were defined in these two locale
  files; other locale namespaces retain their partial translations. Localization generation validates the resulting schema.

### Follow-up verification

Checked candidate: `1bf44616875eeb2d1c0d601d181a5843aa39509a` plus the
runtime, localization and test changes captured by this follow-up commit.
Only this completion record and documentation/status edits followed the pass.

- `./gen.sh i18n`: translation validation and generation passed.
- `fvm dart format` on changed Dart files and the new menu test, plus
  `git diff --check`: passed.
- Changed-file static analysis with
  `git diff --name-only -z -- '*.dart' | xargs -0 fvm flutter analyze --no-pub --no-fatal-infos`:
  passed with zero errors/warnings and 11 informational style lints. Separate
  analysis of `test/core/search/subscriptions/tag_follow_menu_test.dart` passed
  with no issues.
- Focused tag-menu/artist follow run: nine tests passed. It exercises actual tag
  context-menu activation, reactive Follow/Following labels, topic dialog opening
  and cancellation, artist accessibility, theme colors and narrow layouts.
- `./scripts/run_regression_tests.sh`: passed at detected concurrency six.
  **3366 application tests + 934 package/CLI tests = 4300 Flutter/Dart tests**;
  both shell suites and **61 Python tooling tests** also passed. All 16 gates
  completed with no failures or reported skips. The app suite includes the exact
  two-tag refresh regression, safe delta catch-up and the affected subscription,
  backup and navigation consumers.
- Responsive coverage includes the Following action at 240px/2x text, the
  existing search row cases at 240/320px, enlarged-text topic/folder dialogs,
  keyboard-open folder settings and the bulk-follow flow.
- Updated-document local Markdown links passed. Case-insensitive wording scans
  found no remaining user-facing topic pin terminology; remaining push-pin
  icons belong only to window pinning and pinned forum threads.
- Intermediate UI runs exposed stale selectors/text expectations and a
  legacy-membership count assumption. These were corrected before the final
  complete pass. Two runs were interrupted because the new menu-test harness
  was created in the fake async zone; the existing setup pattern resolved that
  test hang. No product timeout was extended.

No device, authenticated live API, CI, merge, push or PR operation was performed.
The snapshot fallback's bounded backlog coverage remains an explicit limitation;
this follow-up does not add account-tier discovery or change cache persistence.
A future combined `develop` candidate requires its own complete gate.


## Follow-up: folder actions, count badges and Topic refactoring (2026-10-15)

Continued from `f39d542cc6603256019904db4f90bb9efe32e0f9`, on the same branch
and isolated worktree. The user chose to keep the existing RSS icons and to show
folder feed shortcuts only when feed mode is enabled.

- Enabled folder cards have a direct RSS feed action before overflow; hidden in
  selection mode and absent for disabled folders. Empty enabled folders open a
  persistent empty feed, using a configured profile only as the cache's legacy
  anchor until topics supply their origins.
- Topic badges show the estimate or lower bound directly (`7`, `7+`), with
  localized accessible count labels. Unknown legacy counts retain NEW; known
  values are no longer duplicated beside a NEW badge.
- Added Name (A–Z) to the existing persisted global sort preference. Topics sort
  by displayed name/query fallback, folders by name. Case-insensitive ties keep
  manual Topic order; sorting never rewrites stored membership or positions.
- The destination title is Following Topics (German: Gefolgte Themen).
- Renamed the runtime domain to `core/search/following_topics`, the model to
  FollowingTopic, folder/organization models to TopicFolder/TopicOrganization,
  caches/views to TopicFeed and the public notifier/provider/backup APIs to the
  same vocabulary. Updated consumers, tests, telemetry enum values and all
  locale namespaces together. Existing code no longer exposes pinned-search or
  following-feed application APIs for local Topics.
- Centralized necessary legacy literals in topic_storage_contract.dart rather
  than changing Hive names, adapter IDs or backup source formats. Settings read
  old aliases and write new keys; legacy deep links redirect to the new route.
  Pixiv native FollowingFeed and AnimeBoxes foreign input models retain their
  correct external terminology.
- Updated the current guide to docs/following_topics.md and repaired Markdown
  links to moved source files. Earlier work-item evidence remains historical.

### Verification of this follow-up

- New UI/compatibility/navigation group: 29 tests passed, including direct folder
  feed activation at 320px/2x text, empty feeds, selection-mode suppression,
  number-only badges and semantics, alphabetical order, legacy Settings aliases,
  new-key precedence and both old route redirects.
- Complete directly affected group: 1210 tests passed across Topics, backups and
  Danbooru artist controls. Legacy source codecs, Hive behavior, AnimeBoxes
  interoperability and transactional rollback remain covered.
- Checked candidate: `f39d542cc6603256019904db4f90bb9efe32e0f9` plus the
  runtime/localization/test changes in this completion commit. Only documentation
  and status edits followed the final complete pass.
- `./gen.sh i18n`: translation validation and generation passed for all renamed
  namespaces and new count labels. Changed and renamed Dart files were formatted
  with `fvm dart format`; staged `git diff --check` passed.
- `fvm flutter analyze --no-pub --no-fatal-infos`: passed across the application
  with **zero errors, zero warnings**, and **174 informational style lints**.
- `./scripts/run_regression_tests.sh`: **passed**, default detected concurrency
  **6**. **3379 application tests + 934 package/CLI tests = 4313 Flutter/Dart
  tests**, both shell policy/release-script suites and **61 Python tooling tests**.
  All 16 required gates completed with no failures or reported skips. Foundation's
  full 65-test suite covers the package touched by telemetry enum renaming.
- Responsive tests cover enabled/disabled/empty folder feed buttons and selection
  mode at 320px with 2x text, badges and their localized semantics at 320px/2x,
  existing narrow search/artist rows, and keyboard-open dialogs. A–Z tests also
  check query-name fallback, stable ties, persisted selection, child folders and
  preservation of manual membership/order.
- Changed documentation links were checked and resolve to the moved guide/source
  files. Topic-runtime old identifier scans now resolve only to the documented
  compatibility contract; native Pixiv and foreign AnimeBoxes concepts remain
  distinct. No temporary icon-preview artifacts were added to the repository.
- Intermediate mechanical-refactor checks found missing consumer/enum references,
  stale titles/menu expectations and foreign/wire fixture keys. These were fixed
  before the final complete pass. New test harnesses also required real async
  initialization and in-test semantics-handle cleanup; the final UI group passed
  without timeout extensions or skipped coverage.

No device, live account, remote publication, merge or PR operation was performed.
Earlier Hive benchmarks remain applicable to the unchanged aggregate format;
this terminology/UI follow-up does not claim a storage performance change. A
future combined `develop` candidate requires its own complete gate.

### Local develop integration (2026-10-15)

- User authorized the local merge. Squashed task commit
  `1059c2653f7af544d761399a6ae86565d8867fb7` onto local `develop`
  `d4e15586f06192f0ff4315d36a3f61ae69a752d5` in a separate integration
  worktree; no conflicts. Existing release version, changelog and changelog test
  were preserved. The primary checkout was left untouched.
- Checked staged candidate tree: `133c464a70d601efd10fdea348514b7fea0e51b6`.
  `./gen.sh` generated missing ignored outputs in the fresh checkout.
  `./scripts/run_regression_tests.sh` passed with detected concurrency 6:
  3379 application tests, 934 package/CLI tests, both shell policy suites and
  61 Python tooling tests. All 16 gates completed successfully.
- Only this documentation entry followed the complete pass. No remote push,
  PR operation or device test was performed.
