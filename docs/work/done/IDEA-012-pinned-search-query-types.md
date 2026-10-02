# Preserve typed pinned-search queries

- Priority: Normal
- Affected feature: Pinned Searches
- Work branch: `fix/pinned-search-query-types`
- Agent/session: `/root/implement_12`

## Problem

Pinned searches currently retain only their canonical executable query. Opening
one therefore restores the whole query as a single raw tag, even when it was
originally built from specific tags.

## Expected behavior

New pins optionally retain their typed tag structure while keeping the existing
canonical query unchanged for duplicate detection and refreshes. Opening such a
pin restores the individual specific tags. Legacy records and unsupported or
future query structures continue to open as one raw query.

## Acceptance criteria

- Pinning a search made only from specific tags stores those individual tags.
- Raw and mixed searches use the existing raw-query fallback.
- Hive persistence, pinned-search backup export, and restore preserve supported
  query structure without requiring migration of existing records.
- Missing, nullable, malformed, or unknown future structure data is treated as
  absent and opens through the raw-query path.
- Structurally valid data whose existing tag conversion does not match the
  canonical query identity is also treated as absent.
- A typed atom containing tab, newline, or another separator that the existing
  query parser treats as multiple tokens is treated as absent, while supported
  literal-space tag spelling remains usable.
- Reusing an existing pin by canonical query does not overwrite its stored
  representation.
- Opening a structured pin selects its owning profile and restores separate
  specific tags; legacy pins still restore the exact raw query.
- Focused tests, static analysis, and the full test suite pass without adding
  analyzer findings.

## Constraints and dependencies

- `SearchSubscription.query` remains the canonical refresh and identity value.
- Backup changes must be additive and backward compatible with source version 1.
- No migration should infer structure from legacy canonical strings.

## Progress

- Claimed and existing query, persistence, backup, import, and navigation paths
  inspected.
- Added optional typed-tag structure across the domain, Hive, backup, import,
  pinning, and navigation paths while retaining the canonical query.
- Added compatibility and observable UI-route coverage for typed, raw, mixed,
  legacy, malformed, and unknown-future inputs.
- Focused verification passed: 166 subscription/backup tests plus the dedicated
  backup-source export test.
- A post-review focused rerun passed all 45 model and navigation tests after
  tightening the public typed-tag invariant.
- Independent review found that valid-looking persisted structure could disagree
  with the canonical query. The domain and backup boundaries now compare the
  existing specific-tag conversion with canonical query identity before keeping
  the structure.
- Review-fix RED reproduced eight unsafe model, Hive, backup, and navigation
  paths; the focused 140-test GREEN run and a post-refactor model/codec rerun
  passed.
- Re-review found that control whitespace could cross a typed atom's token
  boundary before identity normalization. A parser-based single-token guard now
  rejects those atoms without rejecting the supported literal-space alias.
- Separator-fix RED reproduced eight tab/newline bypasses; the focused 148-test
  GREEN run passed.
- Static analysis reports the unchanged baseline of 227 info findings and no
  errors.
- Independent final re-review approved the implementation with no Critical or
  Important findings.
- Final focused verification passed all 226 query model, Hive persistence,
  pinning, navigation, backup codec/import, and backup-source tests.
- The isolated full test suite passed all 1,512 tests.
- A fresh build-runner pass followed by `./gen.sh` produced no tracked generation
  drift; `git diff --check` also passed.
- No Android build was required because this change adds no visual layout and
  its navigation serialization behavior is covered by widget tests.
