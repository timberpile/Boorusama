# Convert AnimeBoxes exports into Boorusama backup data

Priority: Normal

Affected feature or branch: `feature/animeboxes-export-converter`

## Problem

AnimeBoxes exports personal data as a positional, multi-section CSV. The file
is difficult to audit and cannot be imported by Boorusama. It may also contain
plaintext server credentials that must not enter source control or generated
migration artifacts.

## Expected behavior

- A repository CLI command converts supported AnimeBoxes Android 1.0 CSV files
  into readable, versioned, credential-free JSON.
- A second command converts that JSON into Boorusama bookmark, blacklist, and
  pinned-search JSON exports.
- The conversion is deterministic, validates relationships and required data,
  and reports omissions and duplicate resolution without exposing private
  values.
- Profiles and search-history databases are not generated.

## Acceptance criteria

- All six known AnimeBoxes sections are represented in normalized JSON with
  named fields.
- Usernames and credentials never appear in normalized JSON, Boorusama
  exports, diagnostics, committed fixtures, logs, or command output.
- The analyzed 3,347 favorite rows yield 3,346 deterministic Boorusama
  bookmarks after resolving the one repeated site/post identity to its newer
  revision.
- All ten blacklist rules and all 132 pinned searches in six folders are
  represented in their corresponding Boorusama exports.
- Generated bookmark, blacklist, and pinned-search files parse with
  Boorusama's production codecs.
- Converted bookmarks belong to a no-ID `AnimeBoxes` group so each import
  creates a fresh group.
- Malformed or unsupported input fails without leaving partial output.
- Synthetic unit, contract, and CLI tests pass; a synthetic Android import is
  verified with Maestro.
- The source CSV and generated personal output files remain untracked.

## Relevant context

- Design: [AnimeBoxes Export Converter](../../superpowers/specs/2026-09-24-animeboxes-export-converter-design.md)
- Implementation plan: [AnimeBoxes Export Converter](../../superpowers/plans/2026-09-24-animeboxes-export-converter.md)
- Boorusama bookmark backups currently use version 2 stored-post snapshots.
- Pinned-search imports resolve existing profiles by engine and normalized URL
  and already provide a skip confirmation for unmatched profiles.
- Search-history backups are SQLite databases and are deliberately outside the
  first version.

## Dependencies

- Existing Boorusama bookmark, blacklist, and pinned-search backup contracts.
- The repository-local `boorusama_cli` package.
- No remote services or production credentials.

## Claim

- Agent/session: `/root`, current Codex session
- Work branch: `develop` (authorized amendment of the unpushed exporter commit)

## Progress

- Analyzed the private AnimeBoxes export using aggregate and redacted output.
- Agreed on the safe conversion scope, architecture, normalized schema,
  failure behavior, and verification strategy.
- Verified the favorite-column meanings against the AnimeBoxes export method:
  column 22 is the parent ID and column 28 is the favorite-added timestamp.
- Wrote the task-by-task TDD implementation plan and production-codec contract
  strategy.
- Implemented strict CSV parsing, normalized JSON, deterministic Boorusama
  bookmark/blacklist/pinned-search exports, atomic CLI commands, and migration
  documentation.
- Verified the private export twice without logging private field values.
- Verified the blacklist and pinned-search synthetic outputs through the Android
  backup UI, and verified the bookmark payload there before adding the no-ID
  group. The final group shape and fresh-ID behavior have automated coverage.
- The private CSV remains untracked.

## Completion evidence

- CLI validation:
  - `fvm dart analyze`: no issues.
  - `fvm dart test`: all 210 tests passed.
- App validation:
  - `./gen.sh`: passed without tracked changes.
  - `fvm flutter test test/core/backups/animeboxes_migration_contract_test.dart --no-pub`:
    all three production-codec contract tests passed.
  - `fvm flutter test --no-pub`: all 1,484 tests passed.
  - `fvm flutter analyze --no-pub`: completed with 227 existing informational
    lints and no migration-file issue; the repository-wide command exits 1 for
    that baseline.
  - The exporter regression test assigns two bookmarks to file-local IDs 1 and
    2 in an `AnimeBoxes` group with no ID. Production-codec and import-planner
    tests verify that the group decodes and receives a fresh UUID on import.
- Private aggregate validation:
  - Both runs yielded 6 profiles, 1,000 history rows, 3,346 bookmarks from
    3,347 favorites, 10 blacklist rules, and 132 searches in six groups.
  - Both runs were byte-identical and an in-memory scan confirmed that none of
    the source server credential values occurred in any generated file.
  - SHA-256 for the unchanged artifacts: normalized
    `847fb1aa8d9fb30784fca99255b9e1f64f13d5cd334894c69482d605d33d0892`,
    blacklist
    `2a714fe496c63edc0287b2c473c66fb6592592f7ea1d31658db01019792aec0d`,
    pinned searches
    `4f620a6cf027b32e4955374928b083f3239669d58557086ad0679ed31231e70b`,
    and report
    `bb1ec5aa3029d9caab2964bf7f8535bf6079caa2d182a5a38a2ab143d3b14e4e`.
    The earlier bookmark hash was superseded by the added no-ID group after
    the private output directories had been removed.
  - The generated private artifacts decoded through Boorusama's production
    codecs with the expected 3,346/10/132 record counts and complete pinned
    membership. Both exact temporary directories were removed afterward.
- Synthetic Android import:
  - `emulator-5556`: imported the committed blacklist and pinned-search
    fixtures. The blacklist rule `blocked, tag` was visible. Pinned import first
    displayed the expected unmatched-profile preflight, then matched after a
    local Danbooru test profile was configured; `Folder, café` contained the
    ordered `Quoted "title"` search with its query and profile visible.
  - `emulator-5564`: after installing the current dev APK while preserving app
    data, imported the committed bookmark fixture into an empty store. The
    single Danbooru bookmark opened with video controls, the missing-profile
    fallback, and its synthetic character, copyright, and artist details.
- Final five-point review:
  - Secret survival is prevented by discarding source values in the parser,
    canonical sensitive-key validation (including nested underscore/hyphen
    variants), safe diagnostics, command-output tests, and the private
    in-memory scan.
  - Favorite column shifts are protected by exact row-width/field parser tests,
    including parent ID and favorite-added timestamp coverage.
  - Production codec and membership compatibility is protected by
    `animeboxes_migration_contract_test.dart` and the private production-codec
    run.
  - Duplicate selection and ordering are protected by newest/source-position
    tie-break tests, cross-folder ordering tests, and byte-identical runs.
  - Atomic partial-output behavior is protected by the atomic writer and CLI
    failure tests for existing destinations and invalid inputs.
