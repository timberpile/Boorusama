# Allow selecting Merge into before choosing a bookmark target group

Priority: Normal
Affected feature: Per-group bookmark import actions

## Problem and reproduction

Import an AnimeBoxes package with an AnimeBoxes bookmark group and at least one existing local bookmark group. In the imported group's action selector, Update, Merge, New copy, and Skip can be selected. Selecting Merge into closes the menu but leaves the previous action selected; no target group selector appears. The user cannot merge the incoming bookmarks into an existing group.

## Expected behavior and acceptance criteria

- Selecting Merge into immediately retains that mode and displays the available target bookmark groups, even before a target has been selected.
- With no target selected, keep Apply disabled and explain that a target group is required. This intermediate state must not throw or revert the chosen action.
- Choosing an existing group updates the planned changes and allows import once all checks pass. The target remains visible and changeable before confirmation.
- Applying the merge retains the existing target group's identity/name and local members, adds the selected incoming bookmarks, and respects canonical bookmark deduplication. Do not create an additional AnimeBoxes group for this action.
- Switching away from Merge into and back, or changing target, does not retain an incompatible target or apply a stale plan. Preview interactions do not write data.
- Reproduce with the real ImportFlowNotifier and UI action editor in regression coverage, including the unresolved target state and final merge result; a callback-only widget test is insufficient. Verify the reported UI flow.

## Investigation context

`ImportActionEditor` already renders a target selector once Merge into is resolved. However, `ImportFlowNotifier.replaceSource` computes preflight before assigning the new state, and bookmark projection throws `StateError('Group target is unresolved')` for Merge into without a target. This is a code-supported likely cause; the implementer must reproduce the actual transition before fixing it.

Relevant code: `lib/core/backups/export_import/widgets/import_action_editor.dart`, `import/import_flow_notifier.dart`, and `import/import_planned_change_projector.dart`. Inspect directly shared target-action handling for the same transition issue without expanding into unrelated import work.

Relevant documentation: [bookmark groups](../../bookmark_groups.md), [unified import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md), and [AnimeBoxes migration](../../migrations/animeboxes.md).

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation must be delegated in its own branch/worktree. Coordinate with ongoing import tickets before touching shared files.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/data011_merge`; branch `fix/data-011-bookmark-merge-into`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/data-011-bookmark-merge-into`. Implementation queued for the next available slot; review pending.
