# Restore profile editing with UUID IDs

Priority: High
Affected feature: Profile editing on current local `develop`

## Problem and reproduction

Open an existing profile for editing. Instead of the editor, the page shows “Booru not found or not loaded yet”. Profile IDs now use UUID strings, but `updateBooruConfigRoutes` in `lib/core/configs/create/src/routes/routes.dart` still converts the route ID with `toInt()` before comparing it with `BooruConfig.id`.

## Expected behavior and acceptance criteria

- Editing an existing UUID profile opens the correct profile editor from the profile list and other existing edit entry points, including links that select an initial tab.
- Saving an edit updates that profile and preserves its UUID; other profiles remain unchanged.
- Missing or invalid profile references still show the appropriate fallback without a crash.
- Add a regression test exercising the update route with an existing UUID profile, rather than only testing ID serialization or repository updates.
- Verify opening and saving an existing profile through the UI, following the emulator ownership procedure.

## Scope and context

Fix the edit-route regression and inspect directly related edit navigation for remaining integer assumptions. Do not introduce legacy integer-ID migration or expand into an unrelated profile redesign. Related completed work: [IDEA-002](../done/IDEA-002-replace-profile-ids-with-uuids.md) and [UUID implementation plan](../../superpowers/plans/2026-10-03-profile-uuids.md).

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). Implementation must be claimed and delegated in its own branch/worktree. Claimed 2026-10-05 by coordinator `/root`; implementer `/root/profile_edit`; branch `fix/profile-001-uuid-edit-route`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/profile-001-uuid-edit-route`. Implementation and review pending.
