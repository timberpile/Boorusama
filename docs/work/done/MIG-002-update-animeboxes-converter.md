# Update AnimeBoxes conversion for current Boorusama imports

Priority: High
Affected feature: AnimeBoxes CLI migration

## Problem

The converter produces loose JSON, bookmark version 2 without canonical post
identity, and integer pinned-search profile references. Current Boorusama rejects
these outputs after the unified import, profile UUID, and bookmark identity changes.
Its export duplicate check also uses the obsolete engine/media-URL identity.

## Expected behavior

Keep the existing credential-free CSV normalization flow. Export one current
`.bsexport` migration package containing bookmarks, blacklist rules, and pinned
searches, with a separate safe conversion report. The import review explicitly
maps source profile references to existing profiles and preserves unrelated data.
Profiles and search history remain outside the migration scope.

## Acceptance criteria

- Generated packages pass the production package reader, source codecs,
  integrity validation, and import preflight; synthetic import applies through
  the current production transaction/repositories.
- Bookmarks use version 4 and canonical site/upstream-post identities, retaining
  distinct posts that share a media URL and correct AnimeBoxes group membership.
- Pinned searches use stable canonical UUID profile references and retain folder
  and Home ordering. Unmatched profiles require explicit mapping before writes.
- Package metadata and recommended actions do not default to deleting or
  replacing unrelated bookmarks, folders, pins, or blacklist rules.
- Credential removal, deterministic results, complete-input validation, and
  atomic destination preservation remain covered by tests.
- Update migration instructions and replace rejection-only migration tests with
  successful current-format contracts. Run focused CLI/app checks and relevant
  Android UI validation; report any unverified boundaries honestly.

## Context

- [Original migration](../done/MIG-001-animeboxes-export-converter.md)
- [Profile UUID contract](../done/IDEA-002-replace-profile-ids-with-uuids.md)
- [Bookmark identity contract](../done/IDEA-004-stable-bookmark-post-identity.md)
- [Migration guide](../../migrations/animeboxes.md)
- [Development workflow](../../development_workflow.md)

## Claim

- Coordinator/session: Codex `/root`, 2026-10-04
- Implementer: `/root/animeboxes_update`, assigned 2026-10-04; resumed 2026-10-05
- Branch: `fix/animeboxes-current-import`
- Dedicated worktree: `/home/timber/code/Boorusama/.worktrees/animeboxes-current-import`
- Base: current local `develop` at `81be13e3c`
- Authorization: user requested the converter be fixed and brought to the latest
  state after reviewing the concrete compatibility findings.

## Progress

- Converter emits one current `.bsexport` plus a credential-free conversion
  report. Bookmarks use v4 canonical site/post identity; stable source-profile
  UUIDs require explicit mapping. Profiles/history remain excluded and the
  normalization CLI and atomic output safeguards remain intact.
- Per item/New copy recommendations retain unrelated data. Blacklist defaults
  to Skip because the current app supports whole-category Replace only.
- Empty bookmark/pin stores now derive collection semantics from the imported
  source contract. Copied pinned folders allocate unique names consistently in
  preview and apply. Repeated source UUIDs skip recognized existing queries.
  Fresh source UUIDs explicitly mapped to an existing account reuse selected
  queries. A reused pin has one destination: Copy moves selected imported pins
  to the copied folder while preserving local-only membership; Merge keeps
  local-only membership together with imported pins in the chosen folder.
- Canonical port/authority matching rejects ambiguous installations and
  mismatched bookmarks/pins. Normalized site URLs reject query, fragment, and
  user information before output; portable URLs are canonicalized before UUID
  hashing. Removed obsolete loose-JSON output fixtures.
- ZIP bytes use a fixed UTC timestamp. The actual CLI regression reproduced
  cross-timezone byte differences before the fix and now verifies identical
  output under UTC, Europe/Vienna, and America/Los_Angeles.
- Production contracts cover current package reader/codecs/integrity, empty
  payloads, unresolved profile mapping rejection, explicit mapped transaction
  apply, ordering, unrelated local data, repeat Copy, and repeat Merge.
- Complete CLI suite: `fvm dart test --reporter expanded` passed 224 tests.
  Focused 50-test app contract/service/projector run passed. The broader
  `fvm flutter test --no-pub test/core/backups test/core/bookmarks
  test/core/search/subscriptions --reporter expanded` passed 912 tests.
- Targeted analysis passed with no new diagnostics; one existing style info at
  `import_flow_notifier.dart:632` remains. `git diff --check` passed.
- Full `fvm flutter test --no-pub --reporter expanded` finished with 2,149 passes
  and one failure in unchanged bulk-download `session_test.dart`: interrupted
  dry-run background work read a disposed ProviderContainer after test completion.
  The named test passed in isolation and its complete 33-test file passed on
  rerun, indicating a timing-dependent failure. Migration suites passed in the
  full run; no unrelated bulk-download code was changed.
- Final serial confirmation:
  `fvm flutter test --concurrency=1 --no-pub --reporter expanded` passed all
  2,150 tests (exit 0, 8 minutes 11 seconds). The concurrent timing failure did
  not recur. Evidence log: `/tmp/mig-002-app-full-serial.log`.
- Final synthetic actual-CLI artifact is available at
  `/tmp/mig-002-final-review.9zwTDq/export/animeboxes.bsexport`, with its safe report.
- Independent reviewer `/root/animeboxes_review` found no outstanding code
  issues after URL, timezone, and Home-selection repairs. Its actual CLI-to-Hive
  contract run passed all four tests. Coordinator independently ran the final
  CLI command/exporter regressions: 29 passed, exit 0; final diff check passed.
- Android acceptance verified with Maestro on exclusively leased
  `emulator-5558`, using the Dev APK built in this worktree. Normal startup was
  blank on two emulators; the successful launch used software rendering with
  Impeller disabled, preserving existing app data. No startup source changes or
  signed-in credential reads were made.
- Actual final-CLI synthetic package review showed Copy for the group/folder,
  Skip for blacklist, and blocked preflight before explicit profile resolution.
  Explicit Create profile followed by apply completed with Created 5.
  Same-UUID repeat recognized the existing search and completed with Created 1
  (group only), without folder writes.
- A second synthetic source-profile reference was explicitly mapped to that
  existing local profile. Preflight showed Create 1 folder / Update 2 folders;
  apply completed with Created 2 / Updated 2, exercising a real copied-folder
  name collision and reused search without duplicate profile/bookmark creation.
  Both emulator leases were released after testing.
- Initial coordinator acceptance: all ticket criteria verified on 2026-10-05.
  That initial pass used synthetic CSV and controlled variants; real-export
  validation is recorded in the follow-up below. Live remote media was not tested. The parallel-suite timing failure and
  Android rendering workaround remain documented validation limits.
- Ready for user review on `fix/animeboxes-current-import`. Local develop
  integration, remote publication, and branch/worktree cleanup remain separate
  authorized actions; none were performed.

## Real-export follow-up, 2026-10-05

User supplied a real CSV in this ticket worktree and authorized normalization,
conversion, and app import verification. Reopened the same ticket and retained
its dedicated branch/worktree and original implementer. Real user data remains
untracked, outside committed source/tests; private outputs are under
`/tmp/boorusama-animeboxes-real-mfm_4087/`.

- Fresh normalization succeeded: 6 profiles, 1,000 history rows, 3,432 bookmarks,
  10 blacklist rules, 6 folders, and 135 pinned-search definitions.
- Export initially rejected one blank main query. Aggregate inspection showed
  that its `extra_tags` contained valid filters/order, rather than an empty
  search artifact. Current app codecs/repository correctly reject truly blank
  queries; no importer compatibility policy was changed.
- Verified [official AnimeBoxes 2.0.7 APK](https://www.animebox.es/apk/Droidbooru2_0_7.apk)
  `SourceQuery.getExtraTags` and `BooruProvider.generateRequestUrl`: the app
  appends `extra_tags` after main text and trims the combined query. UI selectors
  already represented in that text must not be appended again. Private trace
  evidence is `/tmp/mig-002-source-query-builders.log` (official code only).
- Converter now preserves those extra terms before production query reuse,
  including filter-only pins. Malformed non-text extras and genuinely empty
  effective queries reject before output writes. Unknown/UI settings still
  receive aggregate warnings; profile rating injection and `#fullhd` expansion
  remain outside the conversion scope. Actual input has no `#fullhd` macros.
- All 135 UUID definitions/order remain in the package. The safe report explains
  six repeated source-profile/effective-query identities without exposing query
  values. Expected production identity reuse yields 129 unique pins; the six
  folders contain `[82, 35, 1, 8, 2, 1]` pins and Home remains empty.
- TDD regressions reproduced lost filters, rejection of valid filter-only pins,
  malformed extras accepted, and missing duplicate explanation before repair.
  Final complete CLI suite passed 237 tests; targeted converter analysis reports
  `No issues found!`; `git diff --check` passed. Permanent actual-CLI production
  contract uses a synthetic extras-only pin and passed all 4 tests, covering
  reader/codecs/integrity, mapping, real apply, and repeat behavior.
- Fresh real normalization/export succeeded. Current private package:
  `/tmp/boorusama-animeboxes-real-mfm_4087/export-effective/animeboxes.bsexport`.
  Coordinator independently verified package integrity and absence of source
  credential values in package/report string fields.
- Temporary real-package production reader/codecs/integrity/preflight and
  ImportFlowNotifier/Hive transaction tests passed both blacklist Skip and
  explicit Replace (2 tests, exit 0). Both cases verified all 3,432 canonical
  bookmark identities/group members, 129 unique effective queries, exact source
  folder/member order/counts above, and preservation of unrelated local bookmark,
  group, pin, folder, and mapped profiles. Skip preserved a local rule; explicit
  Replace used all 10 incoming rules. Only aggregate assertions/logs were emitted:
  `/tmp/mig-002-real-package-apply.log`; temporary harness is outside the repo.
- No app production edits were needed for this follow-up. Earlier final full
  serial Flutter suite passed 2,150 tests before this CLI-only repair; focused
  production contracts were rerun after it. Coordinator owns Android real-data
  import, independent acceptance, and final ticket status. No integration,
  remote publication, account operation, or branch/worktree cleanup performed.

- Final independent review approved the bounded effective-query repair and
  updated documentation with no outstanding findings. Reviewer independently
  passed 30 exporter tests and 4 production contracts, verified all real payload
  UUIDs/order/reconstructed queries, and confirmed safe aggregate diagnostics.
- Coordinator Android real-export acceptance passed through the normal file
  picker and current Dev app on exclusively leased `emulator-5558`. Review
  showed New copy for group/folders and Skip for blacklist, and required explicit
  profile resolution before apply. Selected Create profile for all three source
  references; preflight then showed All checks passed and Create 3432 bookmarks,
  Create 1 group, Create 129 searches, Create 6 folders. Import completed with
  Created 3571, including the three profile creations.
- After app restart, Android showed 3432 bookmarks in the AnimeBoxes group and
  all six folders with exactly `[82, 35, 1, 8, 2, 1]` items (129 total). The
  emulator graphics startup issue recurred on restart; launch with
  `enable-software-rendering: true` / `enable-impeller: false` restored the UI
  without data reset. No product startup changes were made.
- The shared Maestro connection was stale after another session restarted the
  emulator pool. An isolated Maestro MCP process recovered UI verification
  without restarting shared services. App stopped, isolated MCP stopped, and
  lease released after verification. No emulator account credentials were read.
- Final real artifact SHA-256:
  `901733ec5bdd481e4c4ed418757344c3deba8083a21c76b8bb54dcbc459db1d6`.
  Both independent real conversions produced identical bytes; package source
  lengths/digests validated and source credential values were absent from
  normalized/package/report string values. Real input files remain untracked.
- Follow-up acceptance criteria verified on 2026-10-05. Ready for user review;
  no local develop integration, commit, publication, or cleanup performed.

## Approved local integration, 2026-10-05

User approved integration as a single commit on local `develop`. Reviewed
changes were replayed onto unchanged base `81be13e3c`; all 25 scoped paths matched
the reviewed worktree before verification. Fresh staged-tree verification:

- Complete CLI suite: 237 tests passed, exit 0.
- Complete serial Flutter suite: 2,150 tests passed, exit 0 (7 minutes 3 seconds).
- Targeted converter analysis: No issues found, exit 0.
- Staged diff whitespace check passed; private CSV/normalized/export files are
  excluded from the commit.

Commit summary: `fix(migrations): update AnimeBoxes exports for current imports`.
Publication and branch/worktree cleanup remain separate authorized actions.
The worktree and personal migration files are preserved.
