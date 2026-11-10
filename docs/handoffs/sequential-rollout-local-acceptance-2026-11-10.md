# Sequential rollout: recovered-state audit and local acceptance handoff

Audit date: 2026-11-10 (Europe/Vienna)
Repository: https://github.com/timberpile/Boorusama
Reference plan: docs/plans/2026-11-09-sequential-integration.md on develop
This handoff is stored on the coordination-only branch maintenance/package-extraction-2026-11-09. **Do not merge that branch or its temporary .github/package-work CI/toolchain files into develop.**

## Purpose, authorization and safety

The remote author's last long-running implementation session was interrupted twice. This document reflects verified GitHub refs, diffs, issue states and Actions logs as of the audit, NOT a claim that P2-P7 were all completed or verified.

The user wants to personally exercise **each package separately**, correct issues with the local agent, then approve its integration into develop before starting the next package's acceptance. P1 was already approved, merged and closed. No approval exists yet to merge P2 or later packages. Do not merge multiple packages as one combined candidate, and do not confuse passing targeted CI with a fully qualified integration candidate.

Before edits: read current AGENTS.md, docs/development_workflow.md, docs/issue_workflow.md and applicable .agents/skills/*. Preserve the primary checkout, uncommitted changes, existing task branches/worktrees and user data. Inspect each existing worktree before attaching a branch. Use FVM, the physical-core test runner, the full final-candidate regression, independent review and scoped leased Android/Maestro acceptance according to repository policy. Do not fabricate tests or waive failed gates. Use only GitHub Issues as the task tracker. No PR or release unless separately requested.

## Grounded package inventory

| Package | Issue(s) | Exact current ref | Status at audit |
| --- | --- | --- | --- |
| P1 | #160, #162 | develop 1affa7dd315bf5838ee27d16f59908a248a4be78 | MERGED, both issues closed |
| P2 | #132 | feature/132-favorites-sync-package at 60f0750315938b53201afc682bcb4e2af8bf5894 | CODE CANDIDATE; targeted CI PASS; final regression, independent review and device acceptance pending |
| P3 | #154 | maintenance/154-content-contracts-package at 054652c4ebc5f9e567fe77920c7e20905bb78c8a | STACKED CODE CANDIDATE on P2; targeted CI PASS; final regression, independent review and local acceptance pending |
| P4 | #155, #158 | feature/155-158-bookmark-library-package at e9a0ab04477bbcc5cd96efe33c95f4eca6246fc8 | STACKED CODE CANDIDATE on P3; CI BLOCKED during init by locale validation; no candidate tests executed |
| P5 | #142 | historical reviewed source 73b63f5fef412800d6106dd78cf5dc3848d28784 | NOT isolated onto the new package chain |
| P6 | #143 | historical source 73087ebf863c4f97a769a2f014e5f2831f4054a6 | NOT isolated; follow-up on bug/156-bookmark-offline-cache at 2fbcc64e68fa2eb40e924d2c75d8217191c462e7 is not a standalone P6 candidate |
| P7 | #156 | historical source 8672cf2ba235fbc810bbcf3296efef1eb4410a37 | NOT isolated; native Szurubooru/live acceptance remains relevant |
| P8 | #140, #141, #161 | older branches + maintenance/combined-testing-2026-11-08 at 252e8954dab8c0842f83a2082c67f4841111c34e | Reference implementation only; no new isolated package prepared in interrupted session |
| P9 | #144 | combined/feature-144 reference | Reference implementation only; no new isolated package prepared in interrupted session |
| P10 | #157 | combined/feature-157 reference | Reference implementation only; no new isolated package prepared in interrupted session; explicitly last |

All #132, #142, #143, #154, #155, #156, #158, #140, #141, #144, #157 and #161 issues were still open in GitHub at this audit. Historical full-regression/review claims in the older stage handoffs describe their exact historical commits, not the newly assembled P2/P3/P4 package heads.

### GitHub Actions evidence

- Run https://github.com/timberpile/Boorusama/actions/runs/42711406363: targeted tests passed for exact P2 SHA 60f0750 (**117**) and exact P3 SHA 054652c (**184**); both jobs succeeded. The CI analyzed lib/packages with --no-fatal-infos, reporting 2,984 informational findings and no displayed error/warning entries. The analyze step was also configured continue-on-error: true, so independently check analysis on the final local candidates.
- Run https://github.com/timberpile/Boorusama/actions/runs/42769186076: repeated successful targeted P2/P3 qualification.
- Run https://github.com/timberpile/Boorusama/actions/runs/42769600555: P4 package assembly succeeded, but verify failed at ./init.sh during i18n validation. Analyzer and Flutter tests were **skipped**, not failed or passed.
- P4 error: de-DE:settings.theme.viewer.groups.all_bookmarks / structure / deleted_subgroups do not exist in base locale. Compare packages/i18n/translations/de-DE.json with en-US.json in P4: German entries were mistakenly placed under settings.theme.viewer.groups, while the English base has them under bookmark.groups. Move those German keys into bookmark.groups without overwriting other translations; rerun i18n validate and ./init.sh before analyzing/testing. More compilation/test failures may emerge afterward and are not ruled out.
- The package verification toolchain GitHub workflow succeeded separately. Its artifacts are transient and are not application qualification evidence. The extraction branch's assembly scripts are staging infrastructure, never product features.

## Strict sequential acceptance and integration procedure

1. Fetch latest refs, inspect existing worktrees and preserve all work. Recheck parent SHAs, branch heads and issue descriptions. Do not checkout a branch into another occupied worktree or reset uncommitted local work.
2. For the current package only, reconcile the **package delta** with the newly integrated develop; original source branches are historical. Do not merge stacked package ancestry in a later stage. Each package must become one independently understandable diff against then-current develop.
3. Format changed Dart files with FVM; run targeted tests, focused analyzer, the complete ./scripts/run_regression_tests.sh on the **exact final integration candidate**, and an independent reviewer. Fix confirmed findings in the owning task branch and rerun affected/full checks as required.
4. Do focused Android/Maestro acceptance where behavior is device-relevant. Follow docs/android_emulator.md, use the exclusive lease, avoid altering real saved content, and verify full emulator/account/app restoration afterward. Use genuine service flows only with authorized test accounts.
5. Present the user a concise German manual checklist with the concrete candidate SHA, what actually passed and any meaningful limitations. Let the user test and decide; **wait for explicit package-specific merge authorization**.
6. After approval, integrate exactly that package into current develop as one Conventional Commit retaining all relevant issue IDs, verify publication and issue closure, clean up only the completed branch/worktree under the repository workflow. Do not close issues while acceptance remains open.
7. Repeat on the newly updated develop. If a runtime/test/dependency tree changes, previous candidate regression evidence cannot qualify the changed integration.

Do not pause productive independent work solely because another package is waiting for user acceptance, but do not advance its integration gate or mix its code into the next already-approved package.

## P2: Favorites Sync (#132), first local acceptance

Branch is a single commit directly on P1 develop. Its scope includes non-destructive target assignment and persistence, plus stable Pixiv account binding across ordinary token rotation. Separate token rotation from a genuine account change; account changes must still fail closed. Save must never fetch, and Save & Fetch must remain explicitly additive.

Start with the server-favorites tests and neighboring Bookmark/target consumers, then full regression and independent review of the **new 60f0750 candidate**. The historical #132 handoff is not a substitute for reviewing this new package delta. Verify runtime on the user's agreed test account and restore test state.

**User acceptance:** assign an already populated Group as the global/per-profile Favorites target; verify all original Posts, Pool/Related items, memberships and dates survive. Check Save, Save & Fetch, repeated fetch, token refresh, an actual account switch, app restart and Default group persistence. Verify manual favorite/unfavorite affects only the intended target membership. No destructive confirmation and no implicit network fetch on Save.

If accepted, squash only the P2 delta to develop (#132); subsequent packages must rebase/replay their own deltas.

## P3: shared Content/Group contracts (#154), second acceptance

P3 current SHA 054652c has parent P2 SHA 60f0750; it therefore includes P2 in history. **Do not merge P3 before P2, and do not squash P2 again.** Compare P2 HEAD to P3 HEAD to isolate its own content-contract delta, then rebase/replay only that delta onto latest develop.

The code adds Content references, Group/Details/member contracts, codecs and access-scoped providers/optional engine capability without activating new native Group UIs. Run contract/identity/pagination/source-isolation tests, impacted Post/Viewer tests, full regression and independent review of the resulting final P3 tree.

**User acceptance:** short application smoke test across normal Post listing/viewer, Bookmarks and existing Pool/Related navigation. No new screens should appear; verify no regression of identities, retained content or source switching. If accepted, integrate only #154.

## P4: unified Bookmark library and hierarchy (#155 + #158), third acceptance

P4 current SHA e9a0ab0 is stacked on P3. The assembled diff from develop touches approximately **293 paths** including backup/import compatibility and UI. Do not interpret its successful git assembly as runtime validation. There may be later-stage reference code copied for hierarchy UX: inspect imported dependencies and reject unrelated P7 activation.

**First unblock:** correct the three German locale keys' nesting as described under Actions evidence; rerun FVM i18n validation and bootstrap. Then format/analyze, run all Bookmark/library/backup/undo/import regression tests, repair resulting compile and runtime failures, run full final candidate suite, independent review (especially recovery/data loss), and non-destructive Android upgrade from real pre-v10 data.

**User acceptance:** backup and restore a copy of the existing library, preserve exact membership dates/IDs/source snapshots, open Structure versus Unified and persist each group mode, navigate folders and direct/subtree views, verify compact picker rows (uniform folder icons, chevron only for child navigation, distinct direct vs nested membership), select/add/remove in all picker modes, create/move/rename, subtree-delete plus Undo, restart and export/restore v10. Confirm no invisible cells/cover geometry instability. Keep unrelated profile-independent import and public access as later stages except compatibility required by v10. Do not mutate the only copy of user data.

Integrate only #155 and #158 after explicit acceptance and full candidate requalification.

## P5: profile-independent import (#142), fourth acceptance

No new P5 integration branch is published. Historical source commit 73b63f5 includes five commits after the original #158 history. Prepare a new isolated P5 branch from **the approved P4 develop**, examine only the original P4-to-P5 delta and reconcile current P4 backup/import changes. Do not wholesale merge the historical branch or combined rollup.

**Critical user-reported defect:** exporting the same current library and importing it with every source set to Replace showed more than 3,000 Bookmark Data changes instead of zero. Reproduce this with real export bytes and semantic comparison, not a count suppression. Fix identity/canonicalization/preview/apply consistency without hiding actual changes. Cover v4–v10 readers, optional missing profile hints, rollback, loaded Details, dates and data integrity. Historical source had completed tests/review on its old parent; repeat on the new candidate.

**User acceptance:** self-roundtrip Replace shows exactly zero genuine changes; importing copied data without matching profiles retains records and hierarchy; mixed-source/legacy files still validate; no unwanted profile creation, removal or account binding. Merge only #142 after full acceptance.

## P6: public/offline access (#143), fifth acceptance

No new P6 integration branch is published. Historical original P5-to-P6 diff had about 106 paths and includes guarded anonymous source policy, media clients, video and image caches. The additional commit 2fbcc64 on bug/156-bookmark-offline-cache repairs Danbooru policy-outage access and URL-key cache reuse, but that branch is **not** directly mergable into newly integrated P5. Extract the relevant fix by file/function, preserving current actor/revocation isolation.

**User acceptance:** imported Bookmarks without matching profiles remain locally manageable; cached thumbnails and full images decode after force-stop and offline restart; saved media cannot leak a different profile's cookies/actor; Gelbooru and Danbooru direct reads work where exact public policy permits. Realbooru anonymous media must use actual verified origins/paths and safe redirects; do not widen arbitrary hosts. Check favicon refresh, video fallback, and unavailable UI listing the actual affected domains/sites and Post IDs (not just a generic count). Verify recovered profile association without rewriting records. Full consumer/regression, native and independent security review are essential. Merge only #143.

## P7: existing source Groups (#156), sixth acceptance

No new P7 integration branch is published. Original P6-to-P7 changes include 17 commits/roughly 143 files for Danbooru Pools/Related and Szurubooru Pools, shared Group viewer routing, identities, saved covers, pagination and public reads. Historical P7 code was independently approved on its old parent, but genuine Szurubooru device acceptance was unresolved in its handoff. The cumulative branch bug/156-bookmark-offline-cache has overlapping later repair work. Reconcile surgically with P4–P6; never fast-forward/merge the 80-commit legacy stack.

**User acceptance:** ordinary Danbooru Pool and Related grids, source order, repeated/missing members, source-specific pagination, sorting/refresh, cover rendering and saved Group actions. Verify two different profiles on the same site never cross-bind actions. Verify Szurubooru with a genuine working instance if available; document concrete service blocker rather than claiming a successful check. Preserve old Pool/Related behavior and bookmark dates. Merge only #156.

## P8–P10: references and UX decisions, NOT implementation-ready

The interrupted remote run did not publish new standalone P8/P9/P10 candidates or finish their previously identified UX problems. Use the old feature branches and combined rollout as **code/design references only**. Reconcile against fully accepted P7 develop first.

### P8 Pixiv Works/Pages and generic viewer (#140, #141, #161)

The **normal existing Post Viewer is the foundation**. Evolve it into a reusable viewer with multi-image support and exactly two coherent presentation states: **Immersive** (only the current centered image/media, normal zoom/pan/next-page interaction) and **Details** (that same image plus the current details-style metadata, description, actions, tags). A single image tap toggles states; a double-tap continues zooming and must not also toggle. Do not keep the old independent overlay and image/details flex toggles that produced four inconsistent layouts. Respect Android system insets/status bar, stable image geometry/zoom, narrow screens and text size. Hide meaningless 1/1 counters.

Outer navigation moves between Works; inner navigation moves between Pages. Define and test unzoomed boundary behavior explicitly with the user before final UX approval, without accidental cross-Work swipes during pan/zoom. Preserve selected Page per Work, independent Work and Page Bookmark actions, correct download/share bytes and source links. Pixiv Browse/Search/Explore must show Works instead of flattened Pages; Explore headers should not all reappear on upward scrolling. Verify #161 filtered/empty-page cursor correctness, Following, Favorites and account isolation. Prior viewer mockups and historic handoffs are design references, not accepted runnable implementation.

### P9 Folder Sync (#144)

Existing combined code implements a significant signed-folder foundation, but the user reported UX/security defects. Require a strictly read-only received mirror at both repository and UI layers, hidden from Bookmark destination pickers, while local rename/move and subscription management remain possible. Receive must display a real hierarchy; Publish from a collection should act directly, not redirect through a global checklist. Sender device name editable; receiver may override locally while defaulting to sender name. Simplify storage root without breaking existing publication data. Explicit signed **Stop Publishing** should delete the receiver's mirror when no other valid subscription keeps it; mere offline/missing files must never delete content. Preserve outside memberships, rollback, anti-resurrection and trust/signature verification. Verify real folder-provider behavior, native Android SAF and two-device paths, not just host tests. Discuss UX with user before finalizing design.

### P10 nhentai (#157), last

Retain source foundation and existing Browse/Search behavior, but replace the unfinished separate Gallery viewer with the same generic two-mode multi-image viewer from P8. Integrate the standalone Search screen into normal profile navigation so it does not trap the user. Verify authentication/API feasibility against real supported endpoints rather than inventing an API-key setting. Test Gallery/Page identities, manifests, tag discovery/persistence, safe media policies and source-switch navigation. Perform final Android UX acceptance with user **only after P8/P9 stabilize**.

## Exact starting commands for the local agent

~~~sh
git fetch origin
git rev-parse origin/develop
git show origin/maintenance/package-extraction-2026-11-09:docs/handoffs/sequential-rollout-local-acceptance-2026-11-10.md
git log -1 --oneline origin/feature/132-favorites-sync-package
git log -1 --oneline origin/maintenance/154-content-contracts-package
git log -1 --oneline origin/feature/155-158-bookmark-library-package
git diff --stat origin/develop..origin/feature/132-favorites-sync-package
git diff --stat origin/feature/132-favorites-sync-package..origin/maintenance/154-content-contracts-package
git diff --stat origin/maintenance/154-content-contracts-package..origin/feature/155-158-bookmark-library-package
~~~

Use the existing worktree helper/status before any worktree operation and follow the actual installed AGENTS.md instructions for every merge. Keep the latest reviewed source and final test results in each package's own English handoff. Provide the user with a short **German**, package-specific device checklist and request acceptance *only at the integration checkpoint*. End the session with a compact cross-package status report, not a combined unreviewable release.
