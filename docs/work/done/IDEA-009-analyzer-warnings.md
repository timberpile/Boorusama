# IDEA-009: Clear analyzer findings

Priority: Normal

Affected branch: `fix/analyzer-warnings`

Agent: `/root/implement_09`

## Problem

The repository currently reports 227 info-level analyzer findings. The findings
obscure new diagnostics and include redundant imports and arguments, missing
override annotations, style migrations, and nullable codec casts.

## Expected behavior

The full repository analyzer completes without findings. Mechanical cleanup
must not change runtime behavior, and persisted or external post data must
remain safe when optional values are absent or malformed.

## Acceptance criteria

- All 227 existing findings are resolved without disabling or suppressing lint
  rules globally.
- Redundant imports, arguments, and missing annotations are corrected without
  changing behavior.
- Collection null-aware migrations preserve the values emitted by codecs.
- Nullable codec/model casts preserve nullable and malformed-data behavior,
  with meaningful round-trip, legacy, and null-value test coverage.
- Focused affected-domain tests and the complete test suite pass.
- `fvm flutter analyze --no-pub` reports no issues.

## Context and constraints

- The baseline consists of 83 `cast_nullable_to_non_nullable`, 63
  `use_null_aware_elements`, 51 `unnecessary_import`, 18
  `annotate_overrides`, 10 `avoid_redundant_argument_values`, and 2
  `non_constant_identifier_names` findings.
- Do not replace nullable casts blindly with not-null assertions. Stored and
  external payloads are untrusted and may legitimately omit optional fields.
- This task has no dependencies.

## Integration decision

2026-10-07: The user approved rebasing `fix/analyzer-warnings` onto current local
`develop`, resolving the remaining findings, and integrating the complete
validated cleanup. This supersedes the earlier decision to retain the branch
only as a reference.

The persisted nested-map normalization remains a functional compatibility fix,
with its own regression coverage, and is included in this approved delivery.
The branch-only standalone extraction ticket is superseded; the existing
POST-008 silent bookmark recovery ticket describes a different change.

## Progress

- Claimed on 2026-10-02 in the dedicated item-09 worktree.
- Inventory grouped by rule and affected codec/domain before edits.
- Added focused malformed-payload fixtures for the eight engine codecs with
  required nullable-map reads. All eight failed with implicit type errors before
  the explicit validation was implemented and pass afterward.
- Replaced unsafe nullable casts with explicit required-value validation,
  migrated optional collection elements, removed redundant imports and
  arguments, added override annotations, and normalized the two identifier
  names without changing their behavior.
- Preserved Hive compatibility by accepting and normalizing dynamically typed
  nested maps with string keys while continuing to reject malformed key types.
- Independent review identified five engine-specific nested payload decoders
  that still required typed maps. A persistence-boundary regression reproduced
  native Philomena, e621, Sankaku, Shimmie2, and Szurubooru data degrading to
  `UnknownPostData`; all five now normalize string-keyed dynamic maps and retain
  their typed payloads while rejecting non-string keys.

## Completion evidence (2026-10-02)

- `fvm flutter test --no-pub test/boorus/posts/rich_post_codec_contract_test.dart test/boorus/posts/interaction_post_codec_contract_test.dart`: 32 tests passed across the dynamic nested-map persistence boundary.
- `fvm flutter test --no-pub test/core/bookmarks/bookmark_pipeline_performance_test.dart test/core/search/subscriptions/search_subscription_repository_test.dart`: 33 tests passed after the Hive-map compatibility correction.
- `fvm flutter test --no-pub`: 1,497 tests passed after the review correction.
- `fvm flutter analyze --no-pub`: no issues found.
- `git diff --check`: clean.

## Rebase and current verification (2026-10-07)

- Continued the existing dedicated worktree as `/root` and rebased its three
  local commits cleanly onto local `develop` at `6bbc84c10`. Reread the current
  `AGENTS.md` and development workflow after rebase. The pre-rebase branch is
  preserved in `/tmp/boorusama-analyzer-warnings-before-rebase-20261007.bundle`.
- The first analysis of the combined tree found 37 issues, including newer
  tests still calling the renamed `TestSearchPost` helper. Updated those calls,
  preserved explicit profile-ID type validation, and corrected the remaining
  mechanical production/test findings without disabling lint rules.
- The initial focused codec, malformed-payload, bookmark persistence, and
  search repository checks passed all 77 tests.
- The inherited generated booru client still used exact-string website lookup,
  although the current generator template already normalizes supported site
  URLs. Seven Realbooru integration checks exposed this stale output. Stopped
  that run, refreshed only booru output with `./gen.sh booru`, and verified all
  32 Realbooru/profile-ID/bookmark-identity checks. No generator inputs changed.
- Final `fvm flutter analyze --no-pub` reports no issues. All 2,623 tests passed
  in the final serial `fvm flutter test --no-pub --concurrency=1` run. Formatting
  of all 72 affected Dart files and `git diff --check` passed. The known libavif
  native-hook rebuild message accompanied a successful test exit.
- Evidence: `/tmp/boorusama-analyzer-rebased-analysis-20261007.log`,
  `/tmp/boorusama-analyzer-rebased-focused-20261007.log`,
  `/tmp/boorusama-analyzer-rebased-refresh-check-20261007.log`, and
  `/tmp/boorusama-analyzer-rebased-full-20261007.log`.
- The combined result is complete and approved for one local Conventional
  Commit on `develop`, followed by verified automatic task cleanup. No remote
  publication, emulator work, or UI behavior changes are part of this delivery.
