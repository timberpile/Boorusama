# Pre-Release Bugfixes and Selected Features — Local Agent Execution Handoff

Date: 2026-11-17. Repository: https://github.com/timberpile/Boorusama

> **Execution authorization:** The owner asked the local coding agent to implement the listed issues **sequentially**, each on its **own issue branch**; to publish a **separate cumulative bugfix preview branch** for owner testing; and to leave every feature on an **independent feature branch** for individual testing. This handoff authorizes those task branches and the bugfix preview branch, **not** integration into develop, PR creation, issue closure, release publication, or branch deletion.

**Goal:** Fix as many of the 11 currently open bugs as can be diagnosed and implemented safely, then prepare the five selected features, while allowing the owner to test all bugfixes together and each feature alone.

**Architecture:** GitHub Issues are the sole source of task status; issue-linked technical handoffs provide implementation detail. Work in isolated task worktrees, produce small scoped commits, and cherry-pick verified bug commits onto one dedicated preview worktree. Feature branches are based on develop, never on the cumulative bugfix preview.

**Stack:** Flutter/Dart (always use fvm), Riverpod, Kurumi, Android. Follow the repository's current AGENTS.md and development/issue workflows.

**Specifications:** The live issue description, its linked handoff or design, and explicit owner clarifications below. These handoffs contain proposals, **not verified drop-in patches**; recheck their APIs and file paths against the implementation base.

## 0. Preflight: establish the source and avoid taking over existing work

1. Read AGENTS.md, docs/development_workflow.md, docs/issue_workflow.md, and the relevant repository skill before acting. Prefer .agents/skills/debug-issue/SKILL.md for uncertain bug causes, implement-change for a clear fix, design-change for #43's migration, and execute-plan when executing an established design. The repository does not require Superpowers or automatic subagents.
2. Fetch origin; inspect origin/develop, branch/worktree status, current open issue descriptions, latest issue comments, and existing claims. Do **not** reset, stash, detach, or overwrite the owner's checkout or another agent's worktree. Continue an existing task branch only if it is genuinely yours or has been explicitly handed over.
3. **#144 is under active development on feature/144-folder-based-collection-sync and is near merge. Do not implement it or duplicate any of its outstanding work.** Prefer starting new bug branches from origin/develop **after #144 has actually landed**. If it has not merged and work can proceed independently, use the current origin/develop, note the base SHA, and later reconcile carefully with the updated base before proposing integration. Pause any conflict with #144 for coordination; never overwrite #144.
4. Confirm that the 11 bug issues below remain open; if one is already fixed in current develop, verify the behavior with a focused test, document the evidence on its issue, and skip redundant code. Likewise check for existing branches before opening a new one.
5. Issue labels and short claim comments may be updated for the issue being worked on. Use one active issue at a time. Do not mark an issue complete merely because a task branch or preview branch has been pushed.

## 1. Branch strategy and authorization boundaries

### Isolated branches

- For each bug, use **bug/<issue-number>-<short-slug>**; for each feature, **feature/<issue-number>-<short-slug>**. Keep established branch names if work has already begun. Use the repository worktree helper when appropriate; otherwise create a separate worktree from the intended origin/develop SHA. Never implement multiple unrelated issues directly on the same source branch.
- Record the original source commit SHA for every task. Commit only the issue's code, focused tests, and essential documentation. Use descriptive Conventional Commit messages mentioning the issue number and/or Refs #N; **do not use Closes #N** while owner acceptance is pending.
- Push each finished issue branch to origin and retain it. Do not rebase/force-push a branch somebody else uses, open PRs, merge into develop, close issues, or delete branches without separate owner approval.
- If a fix needs multiple commits, keep an ordered list of its commit SHAs. If a later change depends on another bug, state that dependency; do not silently combine tasks in one issue branch.

### One cumulative bugfix preview (owner's test build)

- Create a **separate maintenance/pre-release-bugfix-preview-20261117** branch/worktree from a known origin/develop commit, ideally the first develop commit that includes #144. Verify that the name is not already in use by another agent. If it exists as this task's preview, inspect and continue it; never reset it.
- After each bug branch has passed **short, relevant** checks and has a reviewable diff, cherry-pick that issue's commit(s) into the preview branch in the approved order. Preserve source attribution (for example, cherry-pick -x); record the exact issue branch tip and preview commit SHA. Do not merge the complete feature branch history or unrelated develop work.
- Review and resolve any preview-only conflict without changing the original issue branch in place. If a conflict would require a substantial redesign, stop the preview integration of that issue, keep its task branch available, and report the blocker. Do not push a partially resolved or failing preview state.
- Run a **short set of affected tests** on the combined preview after each inclusion, with special attention to previously integrated overlapping components (Pixiv, scrolling/navigation, backup state). Push the preview **incrementally**, not just at the end, so the owner has a recoverable branch for Android builds. The preview must stay intentionally separate from develop.
- If #144 lands after the initial preview base, do not rewrite published preview history. Coordinate a clean, separately verified preview update/integration strategy and record the final base. Never force-push a shared test branch.
- The preview is **for manual testing, not automatically release-ready**. A later approved develop integration must satisfy AGENTS.md's full-suite gate on the final combined candidate.

### Features must remain individually testable

- Implement each selected feature in its own branch based on the appropriate origin/develop commit, **not on the bugfix preview** or another feature branch. Publish each branch separately and supply the exact branch/SHA to the owner.
- Feature #173 (persistent backup-failure notification) must account for bug #172 (backup-folder error recovery). Ideally wait until #172 has been owner-accepted and integrated into develop; do **not** pull the whole bugfix preview into the feature branch. If that prerequisite is not available, leave #173 pending and continue with other independent features.
- Do not promote any feature to the cumulative bugfix preview. No auto-merging features into develop.

### Concrete Git/worktree runbook (adapt paths only after inspection)

For the first bug, after confirming there is no existing branch/worktree and the target base is correct:

    git fetch origin
    git worktree list
    git worktree add -b bug/122-profile-reordering .worktrees/122-profile-reordering origin/develop
    git -C .worktrees/122-profile-reordering status --short

If local develop is demonstrably up-to-date, the repository's scripts/agent_worktree.py helper is also appropriate. Never force-create a colliding branch. Repeat with an exact issue-based slug for **each** later task, always starting a fresh branch from the intended develop base rather than from the previous bug or the preview.

Create the single preview worktree **once**, after inspecting remote branch availability and choosing the #144-inclusive base if available:

    git worktree add -b maintenance/pre-release-bugfix-preview-20261117 .worktrees/pre-release-bugfix-preview origin/develop

After a bug branch is committed, pushed and short-tested, replay its **exact issue-owned commits** in chronological order into the preview. For a single-commit example:

    git -C .worktrees/pre-release-bugfix-preview cherry-pick -x <issue-commit-sha>
    git -C .worktrees/pre-release-bugfix-preview status --short
    git -C .worktrees/pre-release-bugfix-preview push -u origin maintenance/pre-release-bugfix-preview-20261117

Before each preview push, verify a clean resolved tree and rerun the few relevant tests in the preview worktree. Do not copy the shell example literally until verifying the actual paths, commit SHA, branch ownership and status. Never force-push, reset the preview to a new base, or silently omit a failing cherry-pick.

Typical **short** checks (choose actual changed files and affected test paths; these are templates, not a command to run the whole app):

    fvm dart format <changed-dart-files>
    fvm flutter test --no-pub <directly-related-test-file>
    fvm dart analyze <affected-library-or-file>

Tests should use fakes, mock platform bridges and controlled async completion where possible. Commit/push only after recording the actual results. A plugin/platform integration that cannot be covered without an Android run remains **pending owner's manual validation**.

## 2. Verification budget and stop rules

The owner explicitly requests **short tests only** and will perform **final Android/live-service acceptance** personally.

For each issue:

1. Inspect the real current code path and establish a source-backed root cause (or clearly label a hypothesis). When practical, write one focused failing unit/widget regression test that demonstrates the problem.
2. Implement the smallest compatible fix; preserve existing behavior on working reference routes.
3. Run fvm dart format on changed Dart files; run the directly affected fvm flutter test file(s) and narrowly scoped analysis only when useful. Select a few short tests; avoid long-running suites, whole-repository analyzer passes, emulator/device/Maestro runs, live-site/API/account tests, backup jobs against real user data, and heavy migration exercises. Do not silently substitute broad live tests.
4. If a supposedly short check becomes lengthy, fails due infrastructure, or needs a device to prove the behavior, stop that check, record exactly what was and was not verified, and proceed only if the remaining evidence is sufficient. Never claim that unexecuted checks passed.
5. Review the diff for scope, UI consistency, null/empty/error states, profile/source isolation, data migration safety and relevant test assertions. Commit and push the isolated branch; include it in the bug preview only when the combination is consistent and focused checks pass. Otherwise leave the issue branch available and report it as unverified/blocked.

**Important reconciliation:** AGENTS.md requires a complete local suite before a change is safe to integrate into develop. That comprehensive gate is **deferred**, not waived. Under the owner's short-test instruction, do not integrate into develop and do not report the preview or feature branches as fully validated. The owner does the final app/device acceptance; any later develop integration needs separately authorized full verification.

**Do not use Astra review agents for the local-agent work.** No automatic expensive reviewer or subagent fan-out is needed.

## 3. Ordered bugs: one isolated branch per issue

For every item below: read the **live GitHub issue first**, inspect any linked handoff, compare working and failing routes, write a focused regression test when feasible, implement the minimal fix, run short checks, push the issue branch, and then cherry-pick into the bugfix preview if locally verified. If a diagnosis cannot be established without live testing, report the uncertainty and move to the next independent bug rather than inventing a large refactor.

### B1. #122 — Fix Profile Reordering and List Consistency

Issue: https://github.com/timberpile/Boorusama/issues/122

- Fix downward drag index handling (suspected double adjustment); preserve upward drag and stable profile identity.
- Make persisted profile ordering consistent in Browse, Search, Favorites, Cross-Profile Lookup, Favorites Sync, export selectors and other existing pickers. Reuse the one stored ordering model.
- Tests: reorder A/B/C first-to-last and last-to-first; persistence, app rebuild, profile creation, stable active profile and representative pickers. Do not touch credentials.

### B2. #96 — Fix Transient Danbooru Profile Errors

Issue: https://github.com/timberpile/Boorusama/issues/96

- Trace Browse profile switching and delayed provider/page initialization. Distinguish intermediate loading from a real error; do not simply suppress all errors or insert timing sleeps.
- Tests: rapid profile switches, stale asynchronous resolution, successful Danbooru load without transient error, real failure remains visible, account isolation/history preserved.

### B3. #174 — Fix Pixiv Browse/Search Work Grouping

Issue: https://github.com/timberpile/Boorusama/issues/174
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/174-pixiv-browse-search-work-grouping.md

- Determine which real Pixiv Browse/Search session routes flatten a Work into separate image Posts. Compare native Work grid with the intentional local-session fallback; do not remove that fallback wholesale.
- One normal multi-page illustration/manga = **one card with multiple Pages**; open the existing Work/Page viewer. Preserve Ugoira, local Post sessions, pagination and profile scope.
- Tests: one multi-page Work/one card, correct Page count and order, viewer navigation, single-page Work, Ugoira, local fallback and query transitions. Do not assume #140 is missing; it is already complete.

### B4. #169 — Fix Pixiv Timeline Refresh State

Issue: https://github.com/timberpile/Boorusama/issues/169
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/169-pixiv-timeline-refresh-state.md

- In the native timeline refresh controller, keep previously loaded Works visible until successful replacement; on failure retain old results. Avoid a duplicate footer spinner while pull-to-refresh owns progress. Use normal first-load placeholders.
- Tests: refreshing with existing content, failure then retry, empty initial load, no duplicate Works, repeated refresh/cancellation, account switch and pagination. Preserve working routes using NativeContentGrid.

### B5. #175 — Fix Pixiv Browse/Explore Navigation Autohide

Issue: https://github.com/timberpile/Boorusama/issues/175
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/175-pixiv-browse-navigation-autohide.md

- **Fails in Pixiv Browse AND Pixiv Explore. Pixiv Search already works** (as do other profiles). This exact distinction supersedes older Browse-only wording.
- Compare Browse, Explore and **working Search** route shells and the navigation chrome scroll-notification forwarding. Do not blindly add a generic NativeContentGrid listener, since Search is a negative control and duplicate delta forwarding would regress it.
- Tests: down hides/up reveals in Browse and Explore; Search and ordinary Browse remain correct; one scroll updates chrome only once; viewer/selection/menu/refresh/pagination exemptions preserved.

### B6. #131 — Keep Favorites Headers at List Start

Issue: https://github.com/timberpile/Boorusama/issues/131
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/131-favorites-header-list-start.md

- In **non-Pixiv Favorites** the navigation Header (title/actions) must scroll away and reappear **only at list top**. When scrolling slightly upward away from the top, **only the Timeline Toolbar** may reveal.
- Pixiv Favorites is already correct; preserve it. Do not alter Pixiv Browse/Explore Header behavior, or apply a global header floating-policy change.
- Tests: scroll down then partially up while pixels > 0, Header remains offscreen but Toolbar appears; at pixels == 0 Header returns; switch profiles/selection mode; keep existing Pixiv Favorites reference test green.

### B7. #146 — Fix Browse Search Toolbar Overlap

Issue: https://github.com/timberpile/Boorusama/issues/146

- Trace Search Bar positioning against the independently revealing Timeline Toolbar. Fix the shared layout/scroll ownership instead of applying profile-specific pixel offsets.
- Tests: downward hide/upward reveal; top/bottom search placements, selected-tag chips, selection mode, narrow width and enlarged text. Neither Search Bar nor Toolbar may obscure the other's controls.
- The older issue body notes implementation was deferred; **the owner's current instruction to process all open bugs supersedes that scheduling note**, without implying device reproduction already occurred.

### B8. #147 — Unify Android Timeline System Bars

Issue: https://github.com/timberpile/Boorusama/issues/147

- Reconcile status/nav bar appearance and inset ownership across Browse and embedded Pool/Related timelines. Use semantic opaque status-bar backdrop and correct icon contrast; honor edge-to-edge, gesture vs three-button navigation and intentional immersive viewer exception.
- Focused widget/theme/inset tests where possible; report exact device-level visual checks **not performed**. Do not force a claim that Android device behavior is fixed without the owner's acceptance.
- As with #146, current owner direction includes this open bug despite its older deferred wording.

### B9. #166 — Fix Missing Pool Bookmark Covers

Issue: https://github.com/timberpile/Boorusama/issues/166

- Fill cover metadata on new Danbooru Pool/Series Bookmarks using eligible cached Post metadata first, then bounded asynchronous fallback; do not delay Bookmark persistence.
- Backfill existing/imported missing covers when visible, with deduplication, bounded retries and source/profile/rating/blacklist safety. Never leak disallowed images, replace valid covers on transient errors or require manual Refresh Pool.
- Tests: immediate eligible cover, imported missing cover, no eligible cover, repeated builds without request storm, transient fetch failure, restricted content and stable Bookmark/group identity. Use fakes, not live Danbooru calls.

### B10. #121 — Show Bookmark Folder Names in Exports

Issue: https://github.com/timberpile/Boorusama/issues/121

- In Custom Export selection, show the current human-readable nested folder names instead of internal group-folder IDs; keep the stable IDs for storage/import/template compatibility.
- Tests: nested folder labels, rename after saved template selection, missing/deleted folder fallback, stable export selection identity and unchanged .bsexport structure.

### B11. #172 — Clear Backup Errors After Permission Recovery

Issue: https://github.com/timberpile/Boorusama/issues/172
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/172-backup-folder-error-recovery.md

- When the user chooses a new writable Android SAF backup directory, validate actual access and promptly clear **only the stale access-related failure**; no new backup should be required. Invalid permission and unrelated backup errors must remain visible.
- Guard against an older in-flight backup failure overwriting successful recovery, cancellation and rapid directory changes. Reuse existing SAF checks and notifier, no duplicate permission system.
- Tests: valid replacement clears, invalid replacement retains warning, unrelated failure retained, in-flight race/cancel handling. Use mocked SAF; owner will test the real picker.

## 4. Ordered features: independent branches, never added to bug preview

Begin only after processing the bug list to the extent practical. Every feature stays independent for the owner's individual testing. If a feature depends on a not-yet-merged fix, defer just that feature instead of smuggling fixes into its branch.

### F1. #171 — Shorten Actionless Informational Toasts

Issue: https://github.com/timberpile/Boorusama/issues/171
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/171-short-informational-toasts.md

- Reuse the Upvoted short-toast duration for Bookmarked and other purely actionless, lightweight success/info confirmations; preferably centralize by semantic toast category.
- Preserve longer Undo/Retry, warning, error and instructional messages. Test durations with a controlled clock and verify existing replacement/queue semantics.

### F2. #168 — Improve Double-Tap Zoom Corner Focus

Issue: https://github.com/timberpile/Boorusama/issues/168
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/168-double-tap-zoom-corner-focus.md

- Map a comfortable inner image region (initial proposal **12% inset per axis**) to the full painted-image focal range; the user should reach actual corners by double-tapping *inside* the visible image.
- Calculate against the painted image rect, not the screen; respect contain-fit letterboxing and existing transforms. Only remap zoom-in focus; preserve second-double-tap restore, pinch/zoom limits, video and comic reading.
- Test square/portrait/panorama/letterboxed images, both extremes and center, continuity near inset, and matrix restoration. Adjust inset only if a specific test/UX reason supports it.

### F3. #170 — Sort Following Topics by Added Date

Issue: https://github.com/timberpile/Boorusama/issues/170
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/170-following-topics-added-at-sort.md

- Add **Added At: Newest/Oldest** to the **topic list**, using persisted FollowingTopic.createdAt and deterministic position/id tie breaks. Do not confuse topic creation with last fetch/last edited date.
- Preserve manual ordering, existing sort persistence, folder scope, imports and read-only received semantics from #144. No timestamp migration.
- Test both directions, equal timestamps, folder switching, sort restore and manually ordered topics.

### F4. #134 — Group Related Posts in Timelines

Issue: https://github.com/timberpile/Boorusama/issues/134
**Latest owner-approved technical handoff:** https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/134-related-one-card-group-posts-toggle-2026-11-18.md

- Implement **after bugfixes**. Reuse #139 canonical direct Related-family identity and #138 shared Mixed Viewer. Series retains priority and **its existing rolling five-result lookahead**. Related no longer uses a distance threshold or two-member minimum: **one verified parent/child-related Post is enough**.
- The first eligible Related Post owns one stable card. Suppress any later visible tile for another Post from the same direct family, however far away or across loaded pages; retain all raw indices for selection, pagination and viewer mapping. Do not treat a generic Danbooru Post as related merely because RelatedFamilyReference.fromPost returns an anchor.
- Prefer a **temporary, projection-local family map** reconstructed from the existing raw list and frozen displayed entries, not a second persistent registry. Preserve frozen cards when later Series metadata arrives; respect source/account, query/filter, cancellation and refresh boundaries.
- Use the existing Series-style Related icon and first member cover. If the complete-family count is already cached, show that one total; **if unknown, display only the icon**—no displayed-member fallback, no question mark, no X/total ratio, and no family count network request.
- Add **one shared temporary Group Posts switch** in current Timeline View Options for supported Danbooru Search/Artist timelines, default ON. OFF projects **all raw Series and Related Posts** in original order without a refetch; ON restores grouping. Do not persist the choice; preserve it through Selection Mode and viewer/Back, and reset on new route/query/profile. Preserve the user's raw scroll anchor where possible. Explicit family queries and Selection Mode always show raw Posts.
- Opening a Related card navigates to the full Related gallery with its normal pagination; no nested/inline viewer. Verify singleton groups, far-apart sibling results, Series overlap/late metadata, source isolation, icon-only/known totals, raw mapping, toggling without refetch, scroll anchor, bounded continuation and viewer Back using short focused tests.
- **#176 is separate:** its future media-first versus member-Timeline viewer mode toggle must **not** be conflated with the #134 Timeline **Group Posts** switch.

### F5. #173 — Notify When Automatic Backups Fail

Issue: https://github.com/timberpile/Boorusama/issues/173
Handoff: https://github.com/timberpile/Boorusama/blob/develop/docs/handoffs/173-persistent-backup-failure-notification.md

- Coordinate with #172's recovery lifecycle. Prefer implementing only once #172 is in origin/develop to keep this branch individually testable; otherwise mark **waiting for #172** and leave it out of other branches.
- Integrate with the existing Android notification infrastructure and long-lived auto-backup failure state, not a Backup settings widget observer. One stable, persistent failure notification; update without spam; tap opens Backup settings; validated repair/success removes it. No sensitive path/content in text, no foreground service for every backup.
- Tests with a fake notification adapter: repeat failures reuse one ID, verified repair cancels, app restart reconciles, tap route, denied permission fallback, unrelated backup failure categories. Owner tests actual notification permission/Android lifecycle.

## 5. Explicit exclusions and coordination

- **#144 Folder-Based Collection Sync:** another agent owns it; await its merge, do not duplicate its MiteMite or Following UX work.
- **#43 Verified Booru Host Aliases:** owner removed it from this pre-release execution list; leave the GitHub issue open and do not implement it here.
- **#55 Undo Reversible Actions and #124 Pixiv Artwork Bookmark Actions:** owner explicitly deferred; do not implement.
- **#176 Unify Group Viewer and Timeline Modes:** future dedicated UX/design issue, not part of this pre-release sequence and not a prerequisite for #134.
- **Bookmark Newest ordering discrepancy:** owner explicitly requested **no issue** for now; do not add work for it.
- **#148 Standardize Timeline Header Scrolling:** not selected for this release implementation. #131's non-Pixiv Favorites exception is mandatory, but does not authorize unrelated #148 redesign.
- **All other open feature issues** are outside this particular sequence unless the owner adds them. Do not quietly expand scope to #136, #167, etc.
- Avoid sweeping Grid/Thumbnail/Toolbar architectural rewrites as collateral cleanup; #144's active work may already affect these surfaces. Recheck the merged source and keep each bugfix narrow.

## 6. Output and acceptance protocol

After each completed or blocked issue, report concisely:

1. Issue number + exact remote branch name + commit SHA + base SHA.
2. Verified cause (or remaining hypothesis), minimal code changes, test added and important compatibility checks.
3. **Exact short commands actually run** with pass/fail; explicitly list emulator, live API, full suite and Android visual checks **not run**.
4. Preview integration: included? exact preview SHA, or why not; conflicts and interactions with prior fixes.
5. Open uncertainties, user-facing acceptance checklist and whether owner should test now.

Provide an updated inventory of remote issue branches and the latest cumulative preview branch at the end. Preserve branches for owner QA. The owner will build and manually test the cumulative **bugfix preview** and each **feature branch**. The owner authorizes or rejects eventual integration into develop separately; at that stage follow the full required test/integration workflow, including issue closing and branch cleanup when approved.

**Do not describe code as released, bugless, fully verified, or merge-ready under this short-test process.**
