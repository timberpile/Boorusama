# Default single-candidate import mappings and keep them editable

Priority: Normal
Affected feature: Import review for pinned searches and following feeds

## Problem

Importing pinned searches requires manually selecting a target profile even when exactly one valid candidate exists. After selection, the mapping control disappears, preventing correction before import.

## Expected behavior and acceptance criteria

- For each required profile mapping, preselect the target when exactly one valid candidate exists, including when its UUID differs from the exported profile UUID. This is an approved change to IDEA-002's explicit-mapping rule for unmatched UUIDs.
- Preserve existing exact-UUID matching and engine/site conflict validation. Use the import planner's valid candidates; do not broaden compatibility merely to obtain one candidate.
- With zero candidates, keep resolution required; with multiple candidates and no exact identity match, require explicit selection.
- Keep the selected target visible and the mapping editable until import confirmation, for automatic and manual selections. Preserve the existing create-profile option where applicable.
- Changing a target replans affected searches/feeds, invalidates previous preflight, and applies only the newly reviewed mapping. Preview interactions must not write application data.
- Cover single, zero, and multiple candidates, changing a previously selected target, and dependent search/feed ownership in regression tests. Verify the visible import flow through the UI.

## Context and scope

Approved by the user on 2026-10-05. Relevant code: `lib/core/backups/export_import/import/profile_mapping.dart`, the dependency planner, and `import_flow_page.dart`. The page currently omits resolved mappings unless they create a profile.

Related documentation: [unified import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md), [IDEA-002](../done/IDEA-002-replace-profile-ids-with-uuids.md), [development workflow](../../development_workflow.md), and [engineering guidelines](../../engineering_guidelines.md).

Limit changes to mapping defaults and continued editability. Dialog layout and repeated dependency messages are separate workitems to be clarified. Implementation uses its dedicated branch/worktree and an implementer subagent.

## Claim and progress

- Claimed 2026-10-05 by coordinator `/root/import_coordinator`; session rooted at `/root`.
- Branch: `fix/data-007-import-profile-mappings`.
- Worktree: `/home/timber/code/Boorusama/.worktrees/data-007-import-profile-mappings`.
- Implementer: `/root/import_coordinator/data007` (assigned).
- Status: implementation pending; no integration or publication authorized.
