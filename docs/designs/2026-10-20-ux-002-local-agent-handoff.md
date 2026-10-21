# Local-agent handoff: implement UX-002 with existing drag selection

> **Historical, completed handoff.** Unified selection is integrated on `develop`
> as `fd7ae8e`. Instructions below describe the original agent assignment;
> do not execute them or recreate repository-local work items. See
> [current post architecture](../post_architecture.md#selection-and-bounded-mixed-origin-preloading)
> and [GitHub issue workflow](../issue_workflow.md).

Date: 2026-10-20

Repository: `timberpile/Boorusama`

Planning baseline: `3bf372bb01ba475659059b459ed3949b39d3cea1` on develop

## Mission

Implement **UX-002 — Unified Post Selection and Action System**, using the current codebase and the [revised selection plan](2026-10-20-ux-002-selection-plan.md). This is an implementation handoff, not a request to restart product brainstorming.

The original UX-002 requirements remain in scope: shared single/multiple-post actions, correct source-aware capabilities, default grid Long Press selection with explicit gesture overrides preserved, desktop modifier selection, and bottom selection controls without hiding ordinary post-page UI.

The user's subsequent decision is binding: the existing **Long Press + Drag** interaction already works well after Selection Mode is active. Reuse it consistently across existing multi-select collections. Do not implement two separate long presses, a new drag engine, or a new bulk-selection mode on every screen.

The revised plan resolves current-code differences and lifecycle rules. Read it before coding. Its source map and acceptance matrix are part of this handoff.

## 1. Repository status and safe setup

At the planning baseline:

- At planning time, UX-002 was a local ticket. Its historical contents are [in Git](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/docs/work/ready/UX-002-unified-post-selection-and-actions.md).
- The completed bookmark membership semantics are documented in [bookmark groups](../bookmark_groups.md).
- The old `docs/ux-002-existing-drag-selection-20261011` branch contains an earlier planning amendment, not the current implementation base. Do not blindly cherry-pick its old ticket over newer work.
- This planning session made no remote repository changes and performed no build, application tests, or device acceptance runs.

Read current `AGENTS.md`, `.agents/skills/execute-plan/SKILL.md`, `docs/development_workflow.md`, `docs/issue_workflow.md`, and the relevant engineering and emulator instructions. Repository-local workflow takes precedence over stale workflow text in older plans. Do not automatically invoke Superpowers or create a PR.

Inspect the current checkout, worktrees, branch claims, and remote head before changing files:

```bash
git status --short --branch
git worktree list --porcelain
git fetch origin
git log -5 --oneline origin/develop
git log -5 --oneline -- docs/work
```

Use the current develop base in a dedicated task worktree. Suggested branch name: `feature/ux-002-unified-selection`. Reuse a compatible existing task branch/worktree if one is already assigned; do not create a duplicate claim or reset an occupied branch. Do not overwrite, stash, reset, or otherwise disturb the user's unrelated primary-checkout changes. Never reset to the planning SHA merely to reproduce this document.

Copy this handoff and its companion plan into `docs/designs/` in the task worktree. Update the existing UX-002 document to reference the revised plan, record BM-008 as completed, and include the agreed app-wide drag scope. Claim the legacy task according to its current workflow; move the existing work item rather than creating a new ticket or issue. Record agent/session, branch, and worktree. If another agent has already started or completed it, reconcile actual work and avoid overwriting their claim.

Implementation and local commits are authorized by this handoff when the user dispatches it. Pushing, merging develop, opening a PR, releasing, force-pushing, deleting branches, and migrating tickets are not authorized by it.

## 2. Establish the real baseline

Read the current counterparts of the pinned files in the plan. Record any material drift from the planning baseline before implementation. Inspect the installed `selection_mode` source via the lockfile and resolved package configuration—not just its pub.dev description or upstream master.

Inventory current selection surfaces. Useful starting searches:

```bash
rg -n --glob '*.dart' \
  'SelectionMode|SelectionCanvas|SelectableBuilder|selectedFrom|DragSelectionOptions' \
  lib packages
rg -n --glob '*.dart' \
  '_selectedGroups|_selectedFolders|_selectedSearches|multiSelect|_selecting' \
  lib/core lib/boorus
```

Include PostGrid consumers, bookmark posts, Topic Feed posts, Bookmark Group/folder selection, and Following Topics/folder selection. Inspect other independently selectable lists/grids, including existing download/tag/backup-related selection where present. Classify hierarchical trees and protected rows explicitly. Do not conclude 'everywhere' from only the main post grid. Feed overview and member-management screens without multi-selection do not need new selection modes.

Add characterization tests for the user's working active-mode hold-and-drag gesture before modifying it. Distinguish a demonstrated regression from an untested theoretical gesture conflict.

## 3. Implement in this order

### A. Stable selection identity and ordering

Build a small reusable adapter around the existing selection package. Keep one authoritative selection state, stable entity keys, an anchor, ordered selectable entries, and safe index mapping. Use origin-aware post keys and typed folder/Topic/group keys. Never use `post.id` alone across sites or a shared missing-identity sentinel.

Cover offscreen loaded items, masonry order, protected cards, progress-row offsets, append versus reorder, and late refresh callbacks. Preserve and integrate the bookmark refresh gate instead of adding a conflicting remapper. The plan defines cancellation/reconciliation and retained-route lifecycle behavior; implement those rules consistently.

### B. Actual input integration

Wire the adapter through real PostGrid items and custom item builders. Active selection owns touch-long-press drag. Outside selection, preserve explicitly configured gestures and the approved default Grid Long Press change. Keep Viewer gestures unchanged.

Use the current Kurumi menu API. `triggers: false` alone is not a safe fix because it also disables right-click/keyboard triggers. Introduce only the narrow backwards-compatible policy needed to suppress competing long presses while preserving secondary click, Context Menu/Shift+F10, focus restoration, and modal Back/Escape precedence.

Implement/test desktop modifiers with actual widget dispatch. Do not assume package support automatically wins over nested item gesture detectors. Do not change the global selection default from manual to auto-activation.

### C. Post action and layout integration

Reuse current action services behind shared one/many-post definitions. Resolve each target's source/account; do not use the global profile for a mixed selection. Snapshot targets before awaits, validate capabilities, preserve safe generic actions, and avoid silent unsupported subsets or unconditional selection dismissal.

Reuse completed BM-008 semantics and Undo. Preserve Topic/folder and Bookmark Group domain actions rather than forcing them through a post registry.

Move post selection controls to the bottom area while retaining ordinary headers/search/filters. Remove the obsolete search selection scroll compensation together with header hiding. Reserve real footer height, not the existing hardcoded 72/36 offsets. Preserve Kurumi text scaling, performance scopes, navigation/activity/profile scopes, and `AnchorHoverGroup`.

### D. Existing non-post multi-select collections

Adapt the Bookmark Group/folder browser and Following Topics/folder list to the same range mechanism. Build selection order from actual selectable entries, not raw builder indices. Skip All/Default special cards and batch-progress/header rows. Preserve recursive Topic actions, confirmations, ID deduplication, source ownership, and existing move/cycle protections.

Complete the remaining local inventory. Verify already-working package consumers instead of refactoring them gratuitously. Record a concrete surface-by-surface result and any genuine blocker.

## 4. Verification requirements

Read the plan's full acceptance matrix. Prioritize these regression risks:

1. Hold-and-drag versus ordinary scrolling, custom actions, context menus, and reordering; active empty selection; auto-scroll and reversing a range.
2. Mixed origins with equal numeric IDs, engine-specific keys, missing keys, and colliding folder/Topic IDs.
3. Lazy/offscreen rows, progress insertion, refresh/reorder/removal during selection, and snapshots surviving asynchronous actions safely.
4. Header/scroll stability, bottom/top search placement, safe areas, main navigation, narrow screens, enlarged text, and keyboard visibility.
5. Retained inactive destinations, route-local profile scopes, modal focus/Back/Escape, and disposal cleanup.
6. Bookmark final-membership Undo and Following folder/Topic bulk semantics.

Use focused controller and real-widget tests first. Locate existing test files before naming them in commands; relevant areas include posts, bookmarks, search/following, navigation, downloads where touched, and Kurumi consumers. Avoid testing only isolated callbacks while bypassing the actual gesture tree.

Follow the pinned FVM setup. Generate only when required by changed localization inputs or missing generated outputs. Detect ordinary test concurrency once:

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
# Pass actual discovered affected test paths to this command:
fvm flutter test --no-pub "--concurrency=$test_workers" <affected-test-paths>
```

Format changed Dart files with `fvm dart format` and analyze the affected scope. A changed Kurumi package requires its complete suite plus relevant consumers.

This task changes shared cross-feature behavior; run the repository's complete local suite on the final candidate:

```bash
./scripts/run_regression_tests.sh
git diff --check
```

Follow `docs/android_emulator.md` before any emulator operation and use an exclusive lease with Maestro for the necessary touch/auto-scroll/system-Back acceptance checks. Do not expose `.test_credentials` in logs, screenshots, reports, or fixtures. Test desktop input using widget tooling and a desktop run where available. Explicitly report unavailable device verification rather than counting it as passed.

A complete suite pass can be reused only for the same runtime candidate; documentation-only report changes do not require rerunning the app suite. Changed runtime code, dependencies, or a different develop integration candidate do. Do not weaken tests, skip failures, or invent successful results.

## 5. Completion report

Commit task changes locally in coherent increments. This historical plan originally tracked acceptance in a local ticket. New work
must use a GitHub Issue and report verification in its ordinary task handoff.

Report the checked commit/base, changed behavior, surface coverage, significant design decisions, exact commands and outcomes, package/application/full-suite results, device coverage, and remaining limitations. Distinguish local task completion from integration readiness and publication authorization.

Do not end with only 'drag selection added': report the unified post actions, layout behavior, state correctness, and all applicable collection surfaces required by UX-002.

## 6. Suggested operator configuration

Recommended local implementer: **GPT-6.1 Sol, reasoning effort `high`**, when available to the user's account/client. This is a task-specific quality/cost recommendation, not a requirement to change repository configuration.

```toml
model = "gpt-6.1-sol"
model_reasoning_effort = "high"
```

Use High for the shared-state/input/action integration and final review. A higher effort can be reserved for a specific unresolved cross-cutting defect; it is not a substitute for running the tests or a reason to use maximum effort for every mechanical edit. Do not change the user's saved agent settings without permission.

Official model and configuration references, checked 2026-10-20:

- https://developers.openai.com/codex/models/
- https://developers.openai.com/codex/config-reference/
