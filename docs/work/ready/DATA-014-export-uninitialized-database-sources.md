# Export empty database sources before their first use

Priority: Normal
Affected feature: Full export; SQLite-backed search history and downloads

## Problem and reproduction

Create a Full export before making a search. Export fails with “The export could not be created: Bad state: Database source is unavailable: search_histories”. Performing one search makes the next export succeed.

The search-history repository creates and initializes its database lazily. `LegacySqliteSourceAdapter.capture` only obtains the database path, then throws when the file does not exist. It does not first ensure that the selected source is initialized.

## Expected behavior and acceptance criteria

- Full export succeeds on a fresh installation before any search or download. Exporting an individually selected unused database source also succeeds.
- Represent a genuinely unused source as valid empty data in the package, preserving full-export completeness. Initialize the source with its real schema or capture an equivalent valid empty database; do not create a zero-byte placeholder.
- Importing that empty source through Replace correctly clears existing target history/download records. This must not silently become Skip because the source was omitted from the package.
- Check both registered SQLite sources: search history and downloads. Preserve existing records when a populated source is exported.
- Distinguish first-use absence from actual initialization, permission, corruption, or read failures. Real failures still fail export clearly rather than producing a successful incomplete backup or overwriting unreadable data with an empty database.
- Add regression coverage for unused-source capture and full-export/import round trip, plus populated-source preservation and real failure handling. Verify Full export before the first search through the visible UI.

## Context and scope

User reported first-use failure and accepted empty-source representation, omission, or reliable availability as possible remedies. Preserve the established Full export contract by choosing valid empty-source representation. No startup-wide eager initialization is required unless necessary for the bounded fix.

Relevant code: `lib/core/backups/export_import/sources/legacy_sqlite_source_adapter.dart`, `lib/core/backups/sources/search_history_source.dart`, `downloads_source.dart`, and the source repository providers. Relevant documentation: [unified export/import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md).

Follow [development workflow](../../development_workflow.md) and [engineering guidelines](../../engineering_guidelines.md). This ticket is unclaimed; implementation must be delegated in its own branch/worktree.
