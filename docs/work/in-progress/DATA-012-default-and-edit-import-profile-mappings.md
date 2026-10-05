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
- Status: implementation and verification complete; ready for coordinator review. No integration or publication authorized.

## Implementation and verification progress (2026-10-05)

- `ProfileMapper` automatically selects exactly one planner-valid candidate, including a different exported UUID. Same-site candidate priority and engine-only fallback remain unchanged. Exact UUID remains the default while same-site alternatives are available to edit; the dependency planner still blocks UUID/engine/site conflicts.
- Import review keeps non-import-supplied mapping cards visible after both automatic and manual selection. The existing Create profile action remains available.
- Existing notifier logic recalculates dependency mappings and replaces preflight on target edits; a real ZIP-load/apply regression verifies replaced preflight and validated-plan objects, changed pinned-search projection, unchanged repository during preview, and final pin/feed/internal-search ownership.
- Red-to-green evidence: four mapper/planner regressions and the resolved-card widget regression failed before the production fix. The initial 34 focused tests passed afterwards; the real notifier ownership regression also passed. The first full suite exposed three superseded explicit-single-candidate assertions in the planner and AnimeBoxes review; those were updated to the approved automatic contract, and all 14 tests in their focused follow-up passed.
- Android Dev APK built successfully (`fvm flutter build apk --debug --flavor dev -t lib/main.dart`, 237.4 seconds). Installed only on exclusively leased `emulator-5560`; every device/Maestro operation was preceded by renewal, and the lease was released after verification.
- Maestro opened a credential-free differing-UUID pinned-search fixture. Review automatically displayed Default profile, All checks passed, and Create profile. Opening the target dropdown and manually selecting Default profile preserved the mapping card and Create profile action. The 9-command assertion flow passed; screenshot: `/tmp/data007-reviewed-mapping.png`. The fixture was left unapplied in review. UI changes to a different existing target are covered by the widget and real notifier regressions; that alternative was not available in the emulator fixture.
- Final full Flutter suite: all 2,155 tests passed in 1 minute 59 seconds (`/tmp/data007-suite-final.log`). Targeted analysis of all changed Dart files has no errors or warnings; three pre-existing informational lints remain (`/tmp/data007-analyze-final.log`). `git diff --check` passed. Ticket remains in-progress for coordinator review.

- Queue ID corrected from DATA-007 to DATA-012 on 2026-10-05 because the old ID already existed in done/. Branch/worktree retained as the same ticket workspace.

- Independent review: no issues found; reviewer reran 44 focused tests successfully. Coordinator reviewed the scoped diff; pending root/user review, remains in-progress.
