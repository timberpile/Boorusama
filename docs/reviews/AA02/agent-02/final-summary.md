# AA02 / agent 02 — Final consolidated audit summary

**Status: closed by explicit user request on 2026-10-30; report-only task complete, verification requirements not fully satisfied.** The user requested a final synthesis and termination instead of completing the remaining active-time and second-pass coverage. This document is the handoff for subsequent consolidation; it does **not** authorize any merge or close implementation issues.

## Audited scope and evidence

- Repository: [timberpile/Boorusama](https://github.com/timberpile/Boorusama); report branch: `review/AA02/agent-02`. Independent source reviews are saved in [branches/](branches/); [inventory](inventory.md) contains each pinned branch SHA and compare merge-base.
- Original assignment: `BATCH_ID=AA02`, `AGENT_ID=02`, `REVIEW_BRANCHES=all`, `MIN_REVIEW_HOURS=5`.
- Baseline at first discovery: `develop` `84df0c2de6cf8fe0177c49babb3fb0eee880f866`; refresh during cycle 2: `894ab270693cdb054a5d527c96182e21e2b14ffc`. Subsequent branch movements were **not** re-reviewed at closure; no integration compatibility is asserted.
- **Cycle 1:** 20 of 20 originally inventoried candidates received a scoped **static** code/test/design review at pinned source, including one docs-only policy candidate. This is coverage of changed source, not a passed test suite.
- **Cycle 2:** 8 of 18 then-active implementation/tooling candidates received a second static pass: T008, T009, T012, T013, T014, T016, T017, T018. The other **10** frozen active candidates (T001–T007, T010, T015, T019) did **not** receive a second pass. T011 (#111) was merged/issue closed and removed as an active target during this audit; T020 was reclassified as docs-only. Cycle 2 was stopped at the user's request, not completed.
- **Verified active duration:** no continuously measured five-hour evidence; **minimum was not demonstrated**. Elapsed clock time between sessions is not active review time.
- **Execution:** no Flutter/Dart/FVM format, analyzer, application/package tests, CI, APK install, emulator, Maestro, real API tests, or on-device acceptance was performed by this audit. Existing authors' handoffs/test claims are not independent audit execution.
- No implementation branches, application code, existing GitHub Issues, PRs, releases, or protected branches were modified by this audit. Its only commits are documentation on the dedicated review branch.

## Canonical findings — 2 defects, 2 risks

| ID | Classification | Target | Finding | Recommended action |
| --- | --- | --- | --- | --- |
| [AA02-A02-F0002](branches/T018.md#aa02-a02-f0002--series-metadata-is-never-fetched-beyond-the-first-40-bookmarked-posts) | **Medium defect; static-confirmed; introduced** | #68 / T018 | Series-membership discovery stops at the first 40 bookmarked Posts for the lifetime of a loaded view. Later visible adjacent Series members cannot group. | Make the request budget viewport/window-based, not a permanent first-40 prefix; add a 45+ bookmark regression. |
| [AA02-A02-F0004](cross-branch-findings.md#aa02-a02-f0004--mixed-origin-postgrid-blacklist-conflates-equal-numeric-post-ids) | **Medium defect; static-confirmed; pre-existing** | Common PostGrid; exposed by #114 / T014 and mixed Feed in #107 / T009 | Blacklist matching stores only numeric post IDs, so post `siteA#42` may hide unrelated `siteB#42`; the new hidden-count indicator can report one while two are excluded. | Retain full source-origin + post-ID identity in count/filter pipeline and add mixed-origin regression tests. Do not attribute original bug to #107/#114. |
| [AA02-A02-F0003](branches/T018.md#aa02-a02-f0003--same-site-second-profile-silently-reuses-the-first-profiles-pool-bookmark) | **Medium risk; high-confidence static path; policy ambiguous** | #68 / T018 | Saving the same Pool from profile B on the same host reuses A's site-only reference/profile hint. If A is removed, it remains bound to A despite B being configured. | Decide explicit shared-vs-per-account Pool identity; either show/rebind bound account or migrate to profile-bound identity, preserving backup/import compatibility and auth isolation. |
| [AA02-A02-F0001](branches/T012.md#aa02-a02-f0001--more-menu-closes-on-benign-action-list-rebuilds) | **Medium UX risk; high-confidence static path** | #112 / T012 | Configurable viewer More menu closes on any new action-list instance, including ordinary favorite/vote provider refreshes on the same post/profile. | Keep security-driven close on actual source/capability changes, but distinguish benign reactive rebuilds; test asynchronous menu interaction. |

**Important distinctions:** F0002 and F0004 are defects established through reachable source control paths, not reproduced on an Android device. F0004 exists at the earlier merge-base and is **not introduced** by the reviewed branches. F0001 and F0003 have real static trigger paths but remain **risks** because intended security/product policy and device impact need confirmation. All four canonical findings remained **open at closure**; no fix was implemented.

### Reproduction and root causes

**F0002 (#68):** With 42+ bookmarked posts, place adjacent known Series members at positions 41/42 with uncached membership. `_warmSeries` uses `entries.whereType<BookmarkPostEntry>().take(40)`, and `_synchronizeEntries` schedules it once; scrolling never advances the discovery window. The request safety limit becomes permanent feature starvation. See [source](https://github.com/timberpile/Boorusama/blob/771082d9c58363348d74b97a2da23732cdd921f0/lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart#L365-L445).

**F0004 (shared controller):** A mixed cached Feed intentionally uses origin-and-ID duplicate identity. Blacklist counting instead accumulates `Set<int>` based on post number alone; a rule matching `siteA#42` also filters `siteB#42`. The new timeline count unions these same numeric IDs. Full origin identity must survive both counting and filtering. See [controller](https://github.com/timberpile/Boorusama/blob/5bb52794468b172b7d6878fb825b42b00d654675/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L604-L675) and [mixed feed](https://github.com/timberpile/Boorusama/blob/5bb52794468b172b7d6878fb825b42b00d654675/lib/core/search/following_topics/src/pages/topic_feeds_page.dart#L988-L1009).

**F0003 (#68):** The persisted Pool identity uses engine+normalized host+Pool ID rather than the profile hint; `PoolBookmarkButton` and add-to-group logic consequently reuse A's stored record when B targets the same Pool. Strict resolution subsequently refuses credential fallback to B (a correct safety guard), leaving an unexpected account binding. Scope and migration must be chosen before code modification. See [Pool button](https://github.com/timberpile/Boorusama/blob/771082d9c58363348d74b97a2da23732cdd921f0/lib/core/bookmarks/src/widgets/pool_bookmark_button.dart#L70-L85).

**F0001 (#112):** `_ConfiguredPostToolbarState.didUpdateWidget` hides More when `oldWidget.buttons != widget.buttons`, but reactive parents rebuild a new List on favorite/vote state changes even when post/profile are unchanged. The existing test explicitly expects callback-change dismissal, so this is a conservative-safety versus menu-reliability trade-off to refine, not a claim of unauthorized action. See [closure check](https://github.com/timberpile/Boorusama/blob/8213b6fbb87cb09d30d5056ad6667821371f22f6/lib/core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart#L99-L109).

## All reviewed targets

| Target | Work item / scope | C1 | C2 | Source-review outcome |
| --- | --- | --- | --- | --- |
| [T001](branches/T001.md) | #97 Follow destination checkbox identity | Yes | No | Stable keyed rows; no new actionable finding |
| [T002](branches/T002.md) | #98 Search editor opaque surface | Yes | No | Full editor backdrop; no new actionable finding |
| [T003](branches/T003.md) | #91 Branded search-link sharing icon | Yes | No | Existing launcher asset; no new finding |
| [T004](branches/T004.md) | #92 Selection Share image fallback | Yes | No | Correct non-video fallback path; potential original-size trade-off, not classified |
| [T005](branches/T005.md) | #95 Artist .bslink sharing and routing | Yes | No | Strict Danbooru profile binding; icon consistent with #91 |
| [T006](branches/T006.md) | #99 Selected-tag suggestion exclusion | Yes | No | Response-local alias closure and reactive filter; no finding |
| [T007](branches/T007.md) | #104 Swipe with expanded details | Yes | No | Source supports mobile horizontal paging; **device UX trial remains** |
| [T008](branches/T008.md) | #106 Live Undo toast insets | Yes | Yes | No source defect; actual Android keyboard/overlay behavior unverified |
| [T009](branches/T009.md) | #107 Cached Feed/Bookmark sorting | Yes | Yes | Local-only sort/pagination preserved; contextual F0004 |
| [T010](branches/T010.md) | #108 Single/batch selection action parity | Yes | No | Origin-bound operations and adaptive dialog; #92/#106 interaction not device-tested |
| [T011](branches/T011.md) | #111 Android update flow | Yes | N/A | Historical static pass; **merged and issue closed** during audit; native install untested here |
| [T012](branches/T012.md) | #112 Configurable viewer toolbar | Yes | Yes | F0001 risk; backup/defaults and action scope inspected |
| [T013](branches/T013.md) | #113 Collection end/pagination | Yes | Yes | No new defect; real complete/partial Pool acceptance outstanding |
| [T014](branches/T014.md) | #114 Unified timeline/blacklist toolbar | Yes | Yes | New count surfaces **pre-existing F0004** |
| [T015](branches/T015.md) | #116 Compact Follow control | Yes | No | No static finding; 48dp hit-area/Android acceptance outstanding |
| [T016](branches/T016.md) | #117 Pixiv Favorites | Yes | Yes | No source defect; live authenticated cursor/privacy cases untested |
| [T017](branches/T017.md) | #118 Pixiv Following Artists | Yes | Yes | No source defect; live API, previews and profile isolation untested |
| [T018](branches/T018.md) | #68 Pool/Series bookmarks | Yes | Yes | F0002 defect, F0003 risk; broad persistence/backup scope |
| [T019](branches/T019.md) | Maestro Android pilot | Yes | No | Host scripts and reset guards inspected; **no live emulator qualification** |
| [T020](branches/T020.md) | Unmerged issue-publication policy proposal | Yes | Excluded | Docs-only; not authoritative until adopted on develop |

No finding for an individual branch means **none independently established at its inspected revision**; it is not an assertion that the branch is tested, approved, integrated or bug-free.

## Other important observations and integration boundaries

- **Existing behavior preserved in inspected source:** #97 checkbox identity, #98 editor opacity, #99 canonical alias filtering, #107 local-only Feed ordering without fetching history, #113 ingestion of a final nonempty page, #114 separate new pin preference and legacy backup compatibility. No runtime guarantees are implied.
- **Shared identity and security are cross-cutting:** #68 Pool references need a deliberate multi-account decision; #92/#108 Share/bookmark mutations must keep post-origin ownership; #117/#118 must be tested against authenticated Pixiv privacy/cursor failures before integration.
- **Responsive/device acceptance:** #104 expanded viewer gestures, #106 OS keyboard/toast overlays, #112 real drag/drop and anchored More, #114 scroll auto-hide, and #116 compact touch targets cannot be qualified solely by their authored widget tests.
- **Tooling-only boundary:** T019's Maestro helper includes emulator/lease/reset safeguards in source, but no host tests, YAML selectors, device reset or actual smoke execution were performed here. T020's unmerged documentation policy is not authorization to publish implementation branches.
- **Existing branch/issue exclusions:** #53 and #76 were already closed with publication evidence; #55 had no ahead-of-develop implementation delta at the initial snapshot. Several open issues lacked discovered task branches and were not silently counted as implemented.
- **No automatic task tracking changes:** The findings are preserved as audit records only. The consolidation/implementation owner should check for existing issue duplicates before creating or modifying GitHub Issues and fix defects on their actual task branches.

## Recommended downstream order

1. Address **F0002** on #68 and add a >45 bookmarked-post scrolling/grouping regression; account for request-bounded metadata and cache coverage.
2. Address **F0004** in common PostGrid with origin-aware blacklist match identities and explicit same-numeric-ID mixed Feed tests. Keep it identified as a pre-existing cross-cutting bug, not a #107/#114 feature regression.
3. Decide **F0003** shared vs independent Pool identity across same-site profiles **before** modifying persisted Pool keys; verify authorization, group badges, migrations/backups/import and profile deletion.
4. Evaluate/refine **F0001** More-menu invalidation and check old-profile callback safety under fast asynchronous state changes.
5. Run targeted FVM tests and analyzer, emulator/Maestro or real service validation for the affected scope, followed by the **complete regression on the final combined integration candidate** as required by current `AGENTS.md`.

## Closure and limitations

This is a **user-directed early audit closure** after cycle 1 and eight second-pass reviews; the originally requested verified five active hours and full cycle 2 were **not met**. All four findings remain unresolved. The documentation and per-branch pinned evidence are complete for transfer to a consolidation/local agent; nothing here declares any implementation branch safe to merge. Keep the report branch and references; do not delete, merge, or close GitHub implementation issues as a side effect of closing this review task.

