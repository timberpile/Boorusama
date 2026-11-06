# Stage 03: import valid Bookmarks without matching profiles

**Issue:** #142. **Branch:** `feature/142-profile-independent-bookmark-import`.
**Base:** reviewed #155 unified storage candidate.
**Goal:** persistence and transfer of valid saved content do not require a locally configured network account.
**Final reviewer:** independent Astra High. Read the [approved contract](approved-contract.md) and live #142 comments first.

This is intentionally after v10 storage, not another implementation of the obsolete dual Post/Collection import model. It does not implement anonymous network access, a new profile wizard or the unavailable-items indicator; #143 owns those.

## Files and interfaces

Inspect/modify existing `lib/core/backups/export_import/import/bookmark_profile_dependency.dart`, `profile_dependency_planner.dart`, `profile_mapping.dart`, `import_preflight.dart`, `import_flow_notifier.dart`, `import_planned_change_projector.dart`, `import_source_integrity_validator.dart`, `import_plan.dart`, `import_transaction.dart`, `import_recovery_gate.dart`, and `lib/core/backups/sources/bookmarks_source.dart`, `bookmark_backup_codec.dart`, `bookmark_backup_data.dart`.

Adapt their existing bookmark-specific result/preview types rather than inventing a parallel import coordinator. Consume #155's unified BookmarkRepository and StoredGroupCodec plus #154 references. Bookmark structural validity and source-access resolution must be separate decisions. Following Topic execution retains its actual profile dependencies.

Create behavioral tests under the existing backup/import test directories: `bookmark_profile_independent_import_test.dart`, `bookmark_profile_independent_roundtrip_test.dart`, `bookmark_unresolved_import_transaction_test.dart`. Reuse current planner/source fakes and real persistence fixtures.

## Task 1: remove only the bookmark profile-blocking dependency

1. Write a fixture containing a valid Post snapshot, Pool/Related references and a native Group snapshot, local groups/folders and dates, but no matching local profiles. New Group fixtures use registered test codecs, not unrecognized future schemas.
2. Assert planning/import succeeds without creating a profile, changing the active profile, fetching media or rewriting source identity. Original non-authorizing profile hints may remain, but cannot become credentials or account bindings.
3. Change bookmark-specific dependency classification so missing/ambiguous profiles are access limitations, not blocking persistence errors. Retain structural schema/key/payload checks and all source integrity checks.
4. Keep unrelated Following Topics, authenticated jobs and explicitly profile-dependent settings subject to their existing dependency requirements. Test a package containing both Bookmarks and a profile-dependent Topic: selecting Bookmarks alone succeeds, executing the Topic still reports the true dependency.
5. Update preview wording using existing concise localized messages. Do not falsely claim imported content can already be fetched. Commit.

## Task 2: preserve unavailable records across every import mode

1. Exercise Merge, Merge Into, Update and Replace through the existing planner/transaction, using unified file-local ID mapping. Preserve full Post snapshots, Group Summary/loaded Details, folders, memberships/dates and Related preference.
2. Test profileless existing record + repeat import -> same compatible local ID, no duplicate, correct membership merge. Later importing a matching profile cannot create another Bookmark or recanonicalize source IDs opportunistically.
3. Test conflicting engine/payload interpretations of the same identity -> preflight conflict and zero writes. Unknown new Group key/schema -> whole preflight failure. Supported codec but no network reader -> retain record. Do not conflate those three cases.
4. Test legacy v9 data reconstructs the same timestamps and references as #155. Missing historical locator/engine evidence remains explicit and retained; no guess from title, image URL, currently selected profile or arbitrary default host.
5. Verify custom selected exports, full backups, clipboard and nearby transfer use the same compatibility path. No separate quick-import bypass of preflight. Commit.

## Task 3: retained-but-unavailable presentation and re-resolution

1. Reuse existing source/presentation fallback reasons to distinguish valid persisted data from usable remote access. Do not display unusable entries as endlessly broken media cards in ordinary grids; retain them in storage and export projections. Cached media may use existing safe offline presentation if actually available and policy allows it.
2. Do not add the #143 count indicator yet. Keep the count/selection projection contract ready for it: unavailable entries remain in total saved membership counts while inaccessible media actions are disabled.
3. Subscribe to the existing profile/access revision boundary so adding/removing a compatible profile recomputes access without import, duplicate writes or a full snapshot rewrite. Never borrow the globally selected unrelated profile.
4. Test missing profile -> add one compatible profile -> media access resolves; two ambiguous accounts -> no arbitrary choice; remove/change account -> remote access revoked while data remains. Retain source-host/profile isolation even if a verified alias facility is later introduced.

## Task 4: transactional and privacy regression

1. Inject failure after import planning, during record writes and during membership publication. Existing import journal/recovery must preserve pre-import state or finish safely on restart; no lost inaccessible entries.
2. Verify cancel and stale source-revision behavior is unchanged. Re-import after recovery is idempotent. No nested mutation lock deadlocks.
3. Export imported data without credentials. Check apiKey/login/cookie/token/provider/controller/current-account state are absent from the new Group path, following the existing Post export policy.
4. Test no HTTP client/request is created merely to prove importability. Access capability is not a hidden validation probe.

## Verification, review and delegation

Run the full existing backup/import/export suites and bookmark suites, affected profile/presentation tests, formatting, analysis, and the complete regression because this crosses shared import/persistence boundaries. Perform a disposable Android scenario: import selected valid Bookmarks without profiles, restart, export, add a matching profile, reopen, remove it and verify data still exports intact. This scenario does not authorize creating or changing real service accounts.

A lower-cost agent may build fixture combinations and update explicit preview strings in disjoint files. The lead owns dependency removal, identity compatibility, import mode semantics and recovery. Astra High independently reviews the complete delta and tests, especially that structural validation was not weakened to make profileless import pass.

Exit only after the actual checks and final review pass. Preserve unresolved network access as a runtime condition, not an excuse to drop data. Write the issue-specific handoff; #142 stays open until authorized shared develop publication.
