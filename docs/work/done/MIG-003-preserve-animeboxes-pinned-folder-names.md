# Preserve AnimeBoxes pinned-search folder names

Priority: Normal
Affected feature: AnimeBoxes CSV normalization and migration package export

## Problem

The converter produces the correct pinned-search and folder counts, but only one folder retains its expected name. Other folders are named Imported folder 1, Imported folder 2, and similar fallbacks instead of their AnimeBoxes names.

## Expected behavior and acceptance criteria

- Identify the actual AnimeBoxes folder-name semantics from the source export and, where needed, the source application's behavior. Preserve each available user-visible folder name through CSV reading, normalization, package generation, and app import.
- Do not infer names from child search text or invent names when the source already supplies one. Keep folder naming separate from ordinary pinned-search query/title handling.
- Use the existing localized/defined fallback policy only for genuinely unnamed folders; retain deterministic uniqueness handling when target format constraints require it.
- Preserve all folder and search counts, IDs, ordering, membership, effective query text, and the converter's credential exclusion.
- Add synthetic regressions representing the actual source naming fields, including named folders with an empty `title`, genuinely blank folders, and duplicate names. Verify package and production import names, not only CSV parsing.
- Review a fresh conversion of the reported real export without committing private names, queries, credentials, or input data.

## Investigation context

Read-only inspection of the existing normalized real-export artifact found six folders, five with blank names. `csv_reader.dart` assigns `AnimeBoxesPinFolder.name` from `SourceQuery.title`; normalization retains that name, and `_exportFolderNames` substitutes Imported folder N when it is blank. The exact source field providing AnimeBoxes' displayed names still needs verification; the implementer must establish it before choosing a fix.

Relevant code: `packages/boorusama_cli/lib/src/migrations/animeboxes/csv_reader.dart`, `normalizer.dart`, and `boorusama_exporter.dart`. Related completed work: [MIG-002](../done/MIG-002-update-animeboxes-converter.md). Documentation: [AnimeBoxes migration](../../migrations/animeboxes.md) and [converter design](../../superpowers/specs/2026-09-24-animeboxes-export-converter-design.md).

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation must be delegated in its own branch/worktree.

## Claim

Claimed 2026-10-05 by coordinator `/root`; implementer `/root/mig003_names`; branch `fix/mig-003-folder-names`; dedicated worktree `/home/timber/code/Boorusama/.worktrees/mig-003-folder-names`. Implementation and review pending.

## Coordinated review status (2026-10-05)

Implementation: `a25610e85`. Independent review approved; converter and production apply checks pass. The supplied original private CSV retains all six folder names, identities, order, and membership; no private contents were committed.

Combined verification is isolated in `.worktrees/nine-release-fixes-review` on `review/nine-release-fixes`. The final combined serial Flutter suite passed all 2,206 tests (exit 0); the unchanged current CLI implementation passed all 239 tests. The final Dev APK built successfully. Analysis of 29 changed Dart files found no errors or warnings; two unchanged baseline const-style informational lints remain. Development integration, publication, and cleanup have not been performed. Keep this ticket in progress pending final combined checks and its remaining acceptance evidence.

## User approval and delivery (2026-10-05)

User tested conversion and explicitly approved integration. On develop all six CLI-to-app contract tests passed. CLI suite passed 238 tests with one 30-second timeout in the timezone subprocess test; that isolated test then passed in 14 seconds without source changes. All 239 CLI cases are therefore verified. Ticket completed; remote publication is not authorized.
