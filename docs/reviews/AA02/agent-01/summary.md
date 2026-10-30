# AA02 / A01 — Final audit summary

**Status: CLOSED BY USER REQUEST (2026-10-30T06:45:29.814Z). Audit protocol NOT fully satisfied.**

Repository: `timberpile/Boorusama`  
Report branch: `review/AA02/agent-01` (documentation only)  
Audit scope: `BATCH_ID=AA02`, `AGENT_ID=01`, `MIN_REVIEW_HOURS=5`, `REVIEW_BRANCHES=all`

This is the independently conducted, source-based review of task branches. The closure is a **user-directed handoff of available findings**, not a certification that five active review hours, all repeat cycles or runtime validation were completed. Application source and original task branches were not modified.

## Executive result

| Measure | Result |
| --- | --- |
| Initial frozen branch/source snapshots | 23 |
| Static first-pass reports | 23/23 |
| Historical/integrated snapshots by the second discovery pass | T001 (#53), T002 (#76), T016 (#111) |
| Remaining active/uncertain implementation/tooling targets | 20 |
| Second-pass adversarial checks recorded | 16/20 |
| Second-pass checks not performed | T019 (#116), T021 (#118), T022 (CI workflow), T023 (workflow docs) |
| Canonical findings | 4: 3 defects, 1 suspected risk |
| Severity and confidence | Medium/static-confirmed: 3; Low/suspected: 1 |
| Lifecycle | 4 open; none resolved, fixed or runtime-reproduced by this audit |
| Executed Flutter/Dart, Python, CI or Android tests | None |
| Requirement of five **verified active** review hours | **Unmet / not substantiated** |
| Last observed `develop` revision | `894ab270693cdb054a5d527c96182e21e2b14ffc` |

The initial baseline was `develop@84df0c2de6cf8fe0177c49babb3fb0eee880f866`. The checked remote `develop` advanced by one commit to integrate #111. The reviewed active task branch heads remained at their pinned revisions in the last remote reconciliation. This summary does not imply any combined integration candidate was built.

## Canonical findings, ordered for remediation

### AA02-A01-F0001 — Pool bookmark identity collision across profiles

**Severity:** Medium. **Confidence:** static-confirmed. **Status:** open.  
**Owner/scope:** [#68](https://github.com/timberpile/Boorusama/issues/68), `feature/group-neighboring-series`, T009.  
**Canonical detail:** [T009/F0001](branches/T009.md#aa02-a01-f0001--pool-bookmark-identity-aliases-different-profiles-on-the-same-site).

`PoolBookmark.identity` combines engine type, normalized host and remote Pool ID without a source profile ID, while `resolvePoolBookmarkProfile` explicitly respects the saved profile hint. When two different accounts use the same host and Pool ID, the button/picker, persistent deduplication and group mutation can select the previously stored reference. A user interacting with profile B can remove or change a reference originally saved under profile A. This is a reachable source path, not a witnessed device execution.

**Next:** Define a stable account-aware identity and a compatibility/migration policy before touching persistence. Update deduplication, UI lookup, cache, Undo and backup/import consistently. Add two-profile/same-host tests for independent group membership, removal, restart and backup round-trip.

### AA02-A01-F0004 — Pixiv Favorites stops when a continuing page is empty

**Severity:** Medium. **Confidence:** static-confirmed. **Status:** open.  
**Owner/scope:** [#117](https://github.com/timberpile/Boorusama/issues/117), `feature/117-pixiv-favorites`, T020; dependency [#113](https://github.com/timberpile/Boorusama/issues/113), T007.  
**Canonical detail:** [T020/F0004](branches/T020.md#aa02-a01-f0004--empty-pixiv-bookmark-pages-prematurely-terminate-the-visible-grid).

The Pixiv cursor session correctly returns `PostResult(posts: [], hasMore: true)` when an inaccessible or filtered page has a valid next cursor. In the #117 branch, `PostGridController` incorrectly derives `_hasMore` from `posts.isNotEmpty`; the next page cannot be reached from the UI. The #117 unit fixture already exercises an empty page with a subsequent nonempty page, but bypasses the grid consumer. The separate, unintegrated #113 branch introduces `_canLoadMore`, honoring `hasMore`.

**Next:** Integrate #113 before or together with #117 (or apply the equivalent generic fix); do not add a Pixiv-specific workaround. Run a true PostGrid widget/integration test of an empty continuing page, subsequent artworks and final nonempty page. Treat a prospective fix as unverified until merged and tested.

### AA02-A01-F0002 — Series warming stops at the first 40 saved Posts

**Severity:** Medium. **Confidence:** static-confirmed. **Status:** open.  
**Owner/scope:** [#68](https://github.com/timberpile/Boorusama/issues/68), `feature/group-neighboring-series`, T009.  
**Canonical detail:** [T009/F0002](branches/T009.md#aa02-a01-f0002--series-grouping-is-never-resolved-beyond-the-first-40-saved-posts).

`BookmarkScrollView._warmSeries` only admits the first `PoolBookmarkCapability.membershipBudget` saved Posts (40) to membership lookup, not the visible/near-visible range. Scrolling farther does not schedule more lookups. Adjacent saved Series Posts beyond that fixed prefix remain ungrouped even though their remote Series could be known. The per-batch request cap is sensible; using it as a lifetime library-prefix cap is not.

**Next:** Warm bounded membership batches as the viewport moves, preserve cache/network limits and selection/scroll stability; test a 50+ Post library with later adjacent Series and source/sort changes. Reconcile intentionally disabled warming while search/source filters are active with the agreed UX.

### AA02-A01-F0003 — Pixiv preview restrictions may fail open on missing fields

**Severity:** Low. **Confidence:** suspected, **not an observed content leak**. **Status:** open.  
**Owner/scope:** [#118](https://github.com/timberpile/Boorusama/issues/118), `feature/118-pixiv-following-artists`, T021.  
**Canonical detail:** [T021/F0003](branches/T021.md#aa02-a01-f0003--preview-safety-flags-default-to-allowing-a-partially-specified-artwork).

The preview predicate `visible != false`, `isMuted != true`, `(xRestrict ?? 0) <= maxRestriction` accepts missing visibility, mute and age-restriction fields as allowed. The DTO explicitly parses these as nullable. This could display a restricted supplied preview when metadata is incomplete, but the Pixiv endpoint may already guarantee safe results. Without real endpoint evidence, it remains a suspected safety risk, not a proven violation.

**Next:** Collect privacy-safe real/sanitized response examples and add null-field policy tests. Only then decide whether to fail closed on missing restriction metadata. Do not introduce unnecessary extra requests.

## Per-branch disposition

The entries below summarize **static source review**, not executed tests or a correctness guarantee. Pinned heads and merge-bases are in [inventory](inventory.md); per-branch rationale and regression requests are in [branches/](branches/).

| Target | Issue/branch | Static outcome and remaining verification |
| --- | --- | --- |
| T001 | #53 — Realbooru prefetch | No finding in older snapshot; integrated into `develop` before this review; live source timing/preload checks absent |
| T002 | #76 — Realbooru original metadata | No finding in older snapshot; integrated; real detail HTML/native values unverified |
| T003 | #92 — selection image share | No source finding; image URL fallback/Original/video separation traced; native sharing and #108 combined check pending |
| T004 | #97 — folder selection identity | No source finding; stable keyed rows and off-folder controlled selection traced; drag/UI run pending |
| T005 | #98 — search editor surface | No source finding; full opaque editor layer and focus exclusions traced; IME transition/device checks pending |
| T006 | #106 — live Undo toast insets | No source finding; root scope, selection footer, viewer obstruction traced; real keyboard and navigation timing pending |
| T007 | #113 — pagination | No defect established in new exhaustion logic; probable generic remedy for F0004; final integration tests pending |
| T008 | Android Maestro MVP | No source finding in safeguards/ZIP scripts/flows; host scripts and disposable emulator scenarios not executed |
| T009 | #68 — Pools and Series | **F0001, F0002**; mixed references, persistence, backups, source isolation and projection need remediation and device tests |
| T010 | #91 — branded search link icon | No source finding; asset and share action wiring checked; native share/visual verification absent |
| T011 | #95 — artist link files | No source finding; strict parser, source-profile selection and `.bslink` dispatch checked; Android open/action verification absent |
| T012 | #99 — selected-tag suggestions | No source finding; canonical, alias and opaque option handling traced; live engine autocomplete/IME unverified |
| T013 | #104 — expanded details swipe | No source finding; prototype gesture arbitration requires explicit real-device acceptance |
| T014 | #107 — local sort | No source finding; score/date fallback and cache-only feed sort traced; compatibility with #68 mixed rows pending |
| T015 | #108 — selection action parity | No source finding; single/batch and source-aware action guards traced; #92/native share and device parity pending |
| T016 | #111 — Android update flow | Historical pinned source checked; issue closed, remote task branch removed and change integrated during audit |
| T017 | #112 — configurable Viewer toolbar | No source finding; settings, backup, auth-scoped menus and responsive projection traced; mobile drag/RTL/keyboard trial pending |
| T018 | #114 — timeline toolbar | No source finding; unique hidden count, live popup and floating/pinned behavior traced; Android scroll/accessibility trial pending |
| T019 | #116 — compact Follow | No finding in first pass; touch target/text scaling must be verified on Android; second pass not performed |
| T020 | #117 — Pixiv Favorites | **F0004**; cursor validation correct in isolation but shared grid prematurely ends on empty pages |
| T021 | #118 — Pixiv Following Artists | **F0003 suspected**; fixed endpoint/account scope traced; real API/privacy validation and second pass absent |
| T022 | Independent review source CI | No source finding; pinned read-only workflow and artifact policies traced; CI never run; second pass absent |
| T023 | Issue branch publication docs | No source finding in normative permission boundaries; no branch operations executed; second pass absent |

Out of scope: protected integration/release branches, other independent reviewer reports, the issue-planning-only branch, and `feature/55-undo-reversible-actions` (zero unique commits ahead of the observed `develop`). Unimplemented open issues without eligible task branches were not converted into code reviews.

## Cross-branch integration considerations

1. **#117 + #113 — confirmed functional dependency (F0004).** Verify exact continuation semantics after combining the fixes, including filtered empty pages.
2. **#68 + #107 — shared Bookmark selector/storage presentation.** The mixed Post/Pool rows and newly added score sort must be reconciled without treating a Pool reference as an ordinary Post, losing tags/date metadata or changing backups.
3. **#92 + #108 — selection Share action.** Both use the unified Post Share sheet, so image fallback should carry through; verify selected-Post source identity and actual native handoff.
4. **#104 + #106 + #112 — Viewer state and overlays.** Gesture ownership, sheet collapse, measured bottom obstruction, popup callbacks and active source must remain coherent through page/profile changes.
5. **#114 + #116 + #106 — responsive timeline/chrome.** Test compact Follow target, floating header, anchored blacklist popup and root Undo clearance together at 320/390/440dp, 2× text and with keyboard/RTL where applicable.
6. **#117 + #118 — Pixiv API/session boundaries.** Verify separate account/follow restriction sessions, token refresh, visibility and authenticated request scope; no redundant artwork fetches or arbitrary next-URL requests.

These items are **integration checkpoints**, not additional canonical defect IDs or evidence of an existing merged-tree failure.

## Verification and unresolved limitations

- **Actually performed:** remote GitHub branch/issue/ref comparison; changed-source and neighboring consumer inspection; authored test inspection; independent branch-level static review and cross-branch reasoning; initial and second discovery reconciliation. A first pass was documented for all 23 snapshots and a second pass for 16 of the 20 current targets.
- **Not performed:** `fvm dart format`, `fvm dart analyze`, `fvm flutter test`, package tests, Python unit tests, CI execution, Android emulator/physical device runs, Maestro, real Pixiv/Realbooru API acceptance, or final combined regression. No test passes are claimed.
- **Active duration:** there is no substantiated ledger of five hours of active review. Timestamp span and the time until this closure cannot be counted as active work. The specified threshold therefore remains **unmet**.
- **Independence:** other AA01/AA02 agents' reports were not inspected. Review branches were observed only as branch names for inventory exclusion. Historical task review handoffs in target diffs were not adopted as defect evidence.
- **Closure:** the user explicitly requested summary and task conclusion. The report is therefore closed **at user request with the above unfulfilled protocol/verification limits**, not marked audit-protocol-complete, integration-ready, fixed or approved for merge. All four findings remain open for the responsible task branch owners and consolidation/local review.

## Recommended next actions for the coordinating/local agent

First triage F0001 (account-aware Pool identity/migration) and F0004 (merge #113's generic continuation behavior with #117); then F0002 (viewport-bounded membership warming). Validate F0003 against real sanitized Pixiv API data before selecting a conservative filter policy. Apply each correction on its respective issue branch, add targeted regressions and preserve unrelated work. Reconcile #68/#107 mixed sort and #92/#108 Share while preparing separate integration candidates.

Run the scope-appropriate `fvm` suites and Android/Maestro checks on real services when authorized. Before **any** integration into `develop`, run the complete repository regression on the final combined candidate under current `AGENTS.md` and `docs/development_workflow.md`. Do not merge, publish `develop`, close source implementation issues, delete source branches or create PRs based on this audit alone.

## Supporting records

- [Frozen inventory, SHA and cycle history](inventory.md)
- [Chronological audit log](review-log.md)
- [Branch-level reports](branches/)
- [Cross-branch findings and dependencies](cross-branch-findings.md)
- [Machine-readable audit manifest](manifest.json)
