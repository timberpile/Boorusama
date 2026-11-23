# Profileless Following imports: local completion and acceptance

Issue: [#187](https://github.com/timberpile/Boorusama/issues/187)

Branch: `feature/187-profileless-following-import`

Examined base: `b81cffd3253a8ac873b293493fb4c3ad9d4619d6`

Implementation/test checkpoint: `5d3b01c1347385064339bb1aa1c5ec77cb06ff43`

Plan: [187-profileless-following-import.md](../plans/187-profileless-following-import.md)

## Local continuation

The follow-up commit completes unavailable-source cards and offline name,
query and Auto-update editing. Topic filtering uses the current saved reader,
and Search manages the specific imported Topic that originated the route.
Portable definitions keep their original source identity across re-export.
Bookmark references continue to match their stored site namespaces.

Host acceptance covers staged package import, re-export and repeat review,
late transaction rollback with a received mirror, source isolation, and narrow
editor layout with enlarged text and the keyboard open. Native file-picker
acceptance and live public media and folder-history checks remain pending.
The local Android emulator timed out during APK installation and hierarchy
inspection.

The sections below record the original implementation checkpoint.

## Status and authority

The core persistence, import planning, preview, export and reader changes are published, together with five new regression-test files. **This is an unverified implementation checkpoint, not an integration-ready result.** There are known test-contract updates and UI completion tasks below. No Flutter/Dart formatting, analysis, test execution, application build or device acceptance has been performed. The environment had no FVM, Flutter or Dart executable. The commit-status endpoint returned no statuses; that is not a successful CI run.

The owner authorized implementation on this task branch and a local-agent handoff. Continue this same branch in its isolated worktree, finish the scoped implementation, review, test and commit changes. Do not create a PR, merge into develop, close #187 or delete the branch without separate authorization. Follow the current repository AGENTS.md and development workflow.

## Implemented behavior and design

### Portable definitions, separate from current access

`FollowingTopicSource` now optionally persists `importedProfileId` and `importedProfileName`. These fields preserve the original portable reference; they never grant account or network authority. Older source JSON remains valid and retains its deliberately fixed local-copy binding behavior. Existing Hive and runtime-snapshot serialization already carries the source JSON, so no new Hive field or backup schema version was introduced.

For a newly unresolved import, the service allocates a collision-checked receiver-local UUID storage namespace, distinct from actual local profiles and incoming profile references. The foreign profile UUID is not reused as local authority. A matching profile appearing or disappearing changes read resolution, not persisted ownership. Ordinary imports that already resolve to a profile retain their existing profile-owned path; this checkpoint does not migrate all existing Topics to portable ownership.

The existing `restoreForProfile` aggregate API populates only a newly allocated empty namespace. The caller's import serialization is important: do not use this mechanism to attach provenance to an existing profile bucket, because aggregate restoration also replaces that bucket's records and runtime sidecars. Created IDs are recorded before restoration so an interrupted write can be cleaned up. Review this boundary carefully during fault-injection testing; a narrow dedicated repository insertion API is preferable if local verification exposes any atomicity or isolation weakness.

### Reader reuse and account isolation

`followingSourceConfigProvider` distinguishes imported sources from existing local copies. Imported sources use a unique exact engine/site-compatible local profile, otherwise the existing allowed anonymous reader, otherwise no reader. Multiple matching accounts do not authorize choosing the foreign UUID as an account. Old local copies still require their chosen account ID and never silently switch to another same-site account.

No saved profiles are created, no public-site allowlist is widened, and no network access occurs in the import service. Existing anonymous transport revocation, credential isolation, query capabilities, rate limits and bounded refresh remain in use. Unknown engines and private sites can be stored even when no reader exists.

### Import, export and preview

`FollowingTopicImportService` no longer rejects or skips valid definitions solely for missing profiles. It preserves source identity, query structure, name, Auto-update preference and normal organization actions. Portable matching uses the original profile reference plus exact site/engine and existing query/destination rules. Reimport can therefore reuse a detached Topic after a real profile appears, while independent Topic records, explicit folder copies and different source references remain distinct.

`followingTopicBackupProfile` exports the retained original reference rather than the synthetic storage namespace or a transient reader account. No credentials or live access scope enter exports.

`ProfileDependencyPlanner` treats only explicitly identified Topic-only consumers as optional. Unknown consumers, actual profile-import errors and legacy standalone feed dependencies remain required. Bookmark hints still cannot choose Topic account authority. Profile reference/site keys now retain the complete normalized URL, including scheme, port and installation path, rather than only the hostname. This transient-key change crosses the Bookmark import boundary: run its consumer tests, not just the new Topic tests.

`ImportPlannedChangeProjector.followingTopics` accepts absent mappings and shares portable matching/construction with execution. It does not fabricate a saved profile. The actual `PackageTransactionSource._applyFollowingTopics` already calls the service under `runSerializedMutation`; no additional package execution bypass was needed. Legacy JSON restore obtains an empty missing-profile discard set from Topic preview, so valid Topics no longer require approval to skip them.

Current folder feeds are ordinary Topic organization and are in scope. The legacy standalone `following_feeds` importer remains profile-dependent; its separate storage/execution model was not broadened.

## Changed runtime files

- `lib/core/search/following_topics/src/types/following_topic_source.dart`
- `lib/core/search/following_topics/src/providers/following_topic_config_provider.dart`
- `lib/core/backups/sources/search_backup_profile.dart`
- `lib/core/backups/sources/following_topic_import_service.dart`
- `lib/core/backups/export_import/import/profile_dependency_planner.dart`
- `lib/core/backups/export_import/import/import_planned_change_projector.dart`

The published service and projector commit diffs were inspected; unrelated folder-import logic and Bookmark/feed projection logic were not replaced. This source review does not prove runtime correctness. The projector file also needs its trailing newline restored by formatting.

## Remaining implementation work, not just verification

1. **Update obsolete tests without weakening unrelated safeguards.** `test/core/backups/following_topic_import_service_test.dart` around the old missing-profile case (base lines 377–420) still expects a blocking exception followed by skipped records. Replace that contract with retained definitions, zero skips and no writes on genuinely invalid input. Inspect `following_topics_source_test.dart`, `export_import/profile_dependency_planner_test.dart`, `data009_profile_dependency_flow_test.dart`, `data009_profile_dependency_messages_test.dart`, `shared_profile_mapping_test.dart` and other import-flow/preflight tests for Topic-only blocking assumptions. Keep legacy feed, real profile conflict, cancellation, stale-plan and transactional failure expectations intact.

2. **Finish unavailable-state UX and editing.** The main page already includes localSource Topics and uses the source-aware reader, but unavailable cards currently receive the generic `mitemite.following_paused` caption. Give a compact, localized source/access explanation and a useful route to an appropriate profile where needed. Verify retention, export, move, delete and name/query editing while inaccessible. `FollowingTopicsNotifier.editLocally` currently requires a resolvable source when retaining a non-profile owner (base lines 1128–1137); preserve valid imported source metadata when an offline/private Topic is edited without attempting a refresh. Do not turn a missing reader into permission to change sites or accounts. Keep NEW unchanged when opening cannot resolve a reader.

3. **Complete source-aware selectors.** `followingTopicHasNewPostsProvider` and `topicFeedHasNewPostsProvider` still filter through saved profile IDs (`following_topic_selectors.dart`, base lines 174 onward), excluding detached anonymous Topics from global badges. The page's profile filter also compares the storage `topic.profileId`. Define read-context-aware display/filter behavior without changing persisted ownership or collapsing independently followed Topics. Check originating-Topic Follow/Following management when the search page's current reader ID differs from the Topic's storage namespace. Do not silently broaden account-bound management matching.

4. **Prove full-flow and recovery parity.** Run a real staged `.bsexport` import with no profiles and compare preview, application and repeat review. Inspect initial recommendation/already-present classification in `ImportFlowNotifier`, explicit remapping, Copy/Merge/Skip and selected ancestor folders. Add a package transaction failure after Topic persistence and verify complete rollback, including original runtime state and MiteMite mirrors. Confirm no placeholder preview namespace is presented as a real profile. Exercise profile-only replacement and restart with retained imports. The inspected `booru_configs_source.dart::_replaceProfiles` removes only old local profile IDs; detached namespaces are not in that removal set, but executable coverage is still required.

5. **Update current subsystem documentation.** `docs/following_topics.md` contains historical and current claims that all imports require profile mappings or skip unmatched definitions. Update only the applicable current behavior, preserving the distinction between ordinary profile-owned Topics, portable imported Topics, received mirrors and legacy standalone feeds.

## Regression coverage prepared, not executed

- `test/core/backups/profileless_following_topic_import_test.dart`: unresolved/public/private/unknown retention, stable export identity, reimport after profile appearance, deletion isolation, independent records/copies, conflicting UUIDs and source JSON compatibility.
- `test/core/backups/profileless_following_recovery_test.dart`: later-record failure cleanup, runtime snapshot round trip, and failed Replace restoration.
- `test/core/backups/export_import/profileless_following_dependency_test.dart`: optional Topic-only references, required shared legacy feeds, full-site separation and transient key identity.
- `test/core/backups/export_import/profileless_following_preview_test.dart`: concrete profileless Replace preview and repeat-import parity.
- `test/core/search/following_topics/imported_topic_access_test.dart`: no saved profiles, anonymous revocation, unique/multiple actors, exact installation matching and legacy fixed-account copies.

The first file's final test exercises source JSON, despite its overbroad snapshot-oriented name; rename it. The recovery file provides the actual runtime-snapshot test. Review all new tests against the pinned SDK before treating them as evidence. They have not had a red/green execution cycle.

## Local verification

Bootstrap the task worktree under the repository's normal FVM instructions. Format every changed Dart file, run `git diff --check`, and run analysis. A focused first pass is:

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" \
  test/core/backups/profileless_following_topic_import_test.dart \
  test/core/backups/profileless_following_recovery_test.dart \
  test/core/backups/export_import/profileless_following_dependency_test.dart \
  test/core/backups/export_import/profileless_following_preview_test.dart \
  test/core/search/following_topics/imported_topic_access_test.dart
```

Then run the affected backup/import, Following, content-access, profile and Bookmark tests, including existing `following_public_access_test.dart`, `local_copy_public_access_test.dart` and MiteMite tests. The full-site profile-key change affects shared import infrastructure, so the complete local suite is required before a ready handoff:

```bash
./scripts/run_regression_tests.sh
```

The final integration candidate must pass the complete suite against its actual develop combination under AGENTS.md; no integration is authorized here. Do not claim integration readiness from targeted tests alone.

Use widget coverage for zero profiles, mixed accessible/unavailable folders, source explanation, profile filtering, NEW badges and edit flows at narrow width and enlarged text, with the keyboard open where relevant. Check public source opening, thumbnail/media loading, bounded manual/automatic refresh, cached folder history and revoked in-flight requests. Use a device only for genuinely native/UI integration that cannot be established by these tests.

Record exact checked commit/state, commands, results, skips and remaining limitations in the acceptance report. Keep #187 open until the repository's separately authorized completion criteria are met.
