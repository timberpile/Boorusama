# Identify the profile in unresolved import mapping messages

Priority: Normal
Affected feature: Problems to resolve in import review

## Problem

Importing pinned searches from three profiles displays “Choose or create a profile for the selected searches and feeds” three times. The messages do not identify their affected profile and mention feeds even when only searches are affected.

## Expected behavior and acceptance criteria

- Show one actionable message per unresolved imported profile reference, naming the incoming profile. Include its website when the name alone is ambiguous.
- Example for searches only: “rule34.xxx: Choose a target profile or create a new profile for the selected searches.” Localize the message and adapt its wording for feeds only or both searches and feeds.
- Multiple selected items depending on the same profile do not produce duplicate messages for that reference. Distinct same-named references remain distinguishable.
- Resolving a mapping removes its problem message; other unresolved messages remain. Deselected or skipped dependents do not leave irrelevant mapping problems behind.
- Keep import blocked while required mappings are unresolved. Preserve distinct validation failures rather than deduplicating unrelated problems by their displayed text.
- Add focused coverage for three unresolved profiles, repeated dependents, ambiguous names, search/feed wording, and resolving one mapping. Verify the visible review flow.

## Context and dependencies

Approved by the user on 2026-10-05. The supplied Android screenshot shows three identical red problem rows under Problems to resolve.

Relevant code: `lib/core/backups/export_import/import/profile_dependency_planner.dart`, `import_issue_message.dart`, and `import_flow_page.dart`; translation key `unresolved_profile_dependency`.

Coordinate with [DATA-012](../in-progress/DATA-012-default-and-edit-import-profile-mappings.md) for mapping state changes and [DATA-013](DATA-013-improve-import-profile-mapping-layout.md) for profile identification in the cards. Keep scope to these dependency messages and their necessary structured context.

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation must be delegated in its own branch/worktree.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/data009_messages`; branch `fix/data-009-profile-problem-messages`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/data-009-profile-problem-messages`. Implementation queued for the next available slot; review pending.
