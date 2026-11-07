# Insert Bookmark hierarchy before resuming the rollout (#158)

## Instruction to the current local rollout agent

The user approved one nested local Bookmark Group model and its detailed browser/picker interaction. **Implement #158 now on the dependent branch, then continue the existing architecture rollout from #142.** This explicitly replaces the pause before #142 recorded in the #155 handoff. Do not restart completed #132/#154/#155 work, and do not skip their unresolved limits when evaluating a later combined candidate.

This handoff publishes requirements and sequencing only. It does not claim #158 runtime implementation or tests, and does not authorize a PR, merge, push to develop, runtime publication, release, or issue closure. Preserve any narrower or separately granted permissions in the current local session.

## Shared references

- Issue: [#158 Unify Bookmark Group Hierarchy](https://github.com/timberpile/Boorusama/issues/158).
- Task branch: `feature/158-unified-bookmark-hierarchy`.
- Parent branch: `maintenance/155-unified-bookmark-storage`.
- Parent including the final documentation update: `f6deb27590a38a812c532c939085742886cdda3f`.
- Parent runtime/test candidate: `6b390c611b5dc4b4dcf8356172635fd698356678`.
- Read [the inherited #155 handoff](155-unified-bookmark-storage.md), [approved specification](../designs/2026-11-07-bookmark-group-hierarchy.md), and [stage 02a implementation plan](../plans/content-architecture/02a-bookmark-hierarchy.md).
- Original rollout plans/review protocol: `maintenance/content-architecture-design` at `fdb68f657284e1f76701c83683aa0228484d09c8`.

The #155 branch was refreshed while this addendum was prepared. Its two new commits change only `docs/handoffs/155-unified-bookmark-storage.md`. The #158 branch was fast-forwarded to include them before any #158 documentation was added. The original #155 branch and develop are not modified by this delivery.

## What the latest #155 documentation changes

The inherited handoff reports #155 locally complete and independently approved, not an unverified draft. It records the exact 6b390c6 runtime, the profile-remapping identity fix, 668 affected tests, the full regression (6,372 application tests, 1,661 package/CLI tests, shell suites and 76 Python tooling tests), disclosed analyzer info findings/skips, and an independent Astra High APPROVE re-review. Read its evidence rather than relying on this abbreviated inventory.

Its Android campaign verifies isolated production storage/codec/migration/helper behavior; it explicitly does **not** prove normal application bootstrap, live-service access, or UI responsiveness. #158 still requires its own normal-UI acceptance, recovery tests and whole-candidate review. Existing durable local artifacts remain under the #155 path recorded there; do not delete or rewrite them. A past blocked tracker-label mutation is not a failed runtime test and must not trigger reimplementation.

The actual implementation still stores local folders separately from Bookmark Groups, even though saved Post/Group records are already unified. Reuse the shared allocator, record indexes, journals, mutation APIs and generic saved-record picker path. Readable unaddressable Posts, opaque legacy Collection data and the latest identity-preservation fix must survive all new conversion/import paths.

## Bring the branch into the local workspace safely

Start with current AGENTS.md and inspect `git status`, worktrees and branch ownership. The task branch already exists remotely. Fetch it and the original planning reference; do not recreate #158 from develop.

```bash
git fetch origin \
  refs/heads/feature/158-unified-bookmark-hierarchy:refs/remotes/origin/feature/158-unified-bookmark-hierarchy \
  refs/heads/maintenance/155-unified-bookmark-storage:refs/remotes/origin/maintenance/155-unified-bookmark-storage \
  refs/heads/maintenance/content-architecture-design:refs/remotes/origin/maintenance/content-architecture-design

git worktree list --porcelain
git branch --list 'feature/158-unified-bookmark-hierarchy'
```

If the #158 worktree exists, inspect and reuse it. If the local branch exists but is not checked out, attach it with `git worktree add` using its exact name. Only when neither exists, create a tracking branch/worktree from the fetched remote branch:

```bash
git worktree add --track -b feature/158-unified-bookmark-hierarchy \
  .worktrees/158-unified-bookmark-hierarchy \
  origin/feature/158-unified-bookmark-hierarchy
```

Do not run the creation command over existing state. From the task worktree, verify the ancestry and source state:

```bash
git merge-base --is-ancestor f6deb27590a38a812c532c939085742886cdda3f HEAD
git diff --stat f6deb27590a38a812c532c939085742886cdda3f..HEAD
git status --short
```

The published #158 delta at handoff consists only of this instruction, its specification and its plan. Preserve later legitimate work instead of assuming the delta must remain documentation-only forever. If the parent has advanced again, coordinate its required fixes with the same rollout owner, update the recorded base and qualify the actual dependent candidate. No force push or destructive reset.

The original plans are on a separate reference. Inspect them without merging old runtime history into this branch:

```bash
git show fdb68f657284e1f76701c83683aa0228484d09c8:docs/plans/content-architecture/README.md
git show fdb68f657284e1f76701c83683aa0228484d09c8:docs/plans/content-architecture/review-protocol.md
git show fdb68f657284e1f76701c83683aa0228484d09c8:docs/plans/content-architecture/03-profile-independent-import.md
```

## Fixed decisions: do not reopen or omit

1. One local nested `BookmarkGroup`, with `parentGroupId`, direct integer Bookmark memberships and their exact dates. Preserve identities and convert empty folders too. Remote Works/Pools/Galleries remain independent saved items, not local folder nodes.
2. Structure shows immediate child groups above the searchable direct Bookmark timeline. All Bookmarks displays/searches the deduplicated local subtree. Queries and autocomplete have matching scope; no search of local group titles.
3. The Header contains the mode control and a clickable group title for ancestor navigation. No permanent browser breadcrumb or extra mode-switch row. Save the explicit mode locally per UUID across restarts; no backup/sync of this UI preference.
4. One vertical scroll surface. Search/filter rows hide on downward scroll and reveal upward inside the timeline, then return to their natural position below the child cards as those cards reappear. Never leave them floating over the child section. Preserve existing Kurumi surfaces and relevant visibility preferences.
5. Picker row body toggles direct membership; the approximately 80 dp trailing region only navigates. Separate touch/focus/semantics targets, with generous row height and usable enlarged text. Leaf groups remain navigable for child creation, and the current group remains selectable.
6. Keep the picker header Back left and Add Group right. System Back, system gesture, Escape and visible Back navigate one hierarchy level; only root Back dismisses. Respect child dialog/IME ownership, do not add custom swipes, and do not pop the underlying viewer.
7. Direct/aggregate mutation targets stay distinct. Preserve Recent, source/identity safety, Default/All, Undo and additive Favorites Sync. Mirror sync, unrelated Following hierarchy changes, and a Related viewer redesign are excluded.
8. Preserve both legacy storage and already-used #155 v2/v10 inputs. Use a distinct local hierarchy generation and explicitly versioned transfer (safe default writer v11 with v4-v10 compatibility). Never silently change what v10 means or flatten an old backup.

Detailed edge cases and class fields are in the specification; implementation phases, source paths and acceptance tests are in stage 02a. Those documents override only the local organization/UI portions of the older plans.

## Execution, delegation and gates

Work autonomously through the plan in this isolated branch. Save coherent commits regularly using `Refs #158`. Use FVM, manual Riverpod and localized `context.t`. Protect the original #155 worktree and unrelated edits.

Delegate bounded fixtures, localization, mechanical consumers and fixed test cases to lower-cost subagents when useful. The lead owns migration/recovery, data identity, scoped mutation and shared scroll integration. Separate file ownership and review delegated output before integration.

Run behavioral tests as each phase changes, then the complete local regression on the final candidate because shared storage/models are affected. Use Android Maestro only with an exclusive emulator lease and preserved/isolated data. Capture actual UI evidence for the scroll boundary and both picker presentations. Do not treat #155's old test run or synthetic native campaign as proof of #158.

Obtain an independent **Astra High** review of the whole final issue delta, not just the last commit. The reviewer must not have written canonical implementation/tests/fixes. Fix findings, retest and obtain independent final re-review. Report exact model/effort and SHA; unavailable reviewer tooling is an explicit gate, not permission to claim an equivalent weaker review. Sol High may handle bounded intermediate reviews, not the final #158 gate.

Keep detailed raw logs under `.worktrees/_artifacts/content-architecture/158/`, not `/tmp` or committed fixtures containing private data. Maintain GitHub as the task tracker, not an additional Markdown progress ledger. Publish only changes covered by actual authorization.

## Resume without losing the insert

Once #158 passes its required tests, Android acceptance and independent review, continue from the verified #158 candidate in the original order:

```text
#155 verified predecessor
  -> #158 hierarchy insert
  -> #142 profile-independent import
  -> #143 profileless display / trusted anonymous reads
  -> #156 existing source Group cutover
  -> #140 Pixiv Work/Page viewer
  -> #141 independent Work/Page bookmarks
  -> #157 native nhentai Galleries
  -> complete combined regression and independent Astra High review
```

Continue existing downstream task branches where already present, reconciling the approved stack without discarding their work. New downstream branches must carry #158, not branch from the old #155-only base. Adapt old folder/v10 assumptions when implementing each stage; keep its original source-feature scope. The instruction to continue is explicit: do not pause again merely because the old #155 handoff said to stop before #142. A real correctness blocker, unsupported product change, or missing publication/integration authority still requires an honest stop/report at that boundary.

At delivery provide the exact #158 commit(s), tested state, actual migration/transfer/UI evidence, independent final review, remaining device limits, and the next stage's base. Preserve issue IDs in later integration subjects. Keep implementation issues open until the agreed verified solution reaches shared origin/develop under separate authorization. No PR or develop merge is requested here.
