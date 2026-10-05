# Unified Export and Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Boorusama's overlapping backup and sharing paths with one safe `.bsexport` workflow for complete personal backups and partial collection sharing.

**Architecture:** Add versioned package and planning contracts in `core/backups/export_import`, bridge each existing source through explicit snapshot/plan/apply/rollback adapters, and let one coordinator own all package I/O and mutation. Existing source codecs remain legacy decoders while new UI, automatic export, nearby transfer, clipboard, and platform entry points all use the coordinator.

**Tech Stack:** Dart, Flutter, Riverpod Notifier/AsyncNotifier, Hive CE repositories, `archive`, `crypto`, `file_picker`, `share_plus`, platform channels, Flutter tests, Maestro Android validation.

**Spec:** `docs/superpowers/specs/2026-10-01-unified-export-import-design.md`

## Global Constraints

- New output uses only `.bsexport`, MIME `application/vnd.boorusama.export`, Apple UTI `com.timberpile.boorusama.export`, and ZIP container version 1.
- Full export dynamically selects every registered source and includes credentials; selected-source failure publishes no package.
- Custom profiles exclude credentials unless their separate toggle is enabled.
- Bookmarks always carry complete `StoredPostSnapshot` data and use `(booru type, normalized site, post ID)` portable identity.
- Collection UUID matches default to Update; identical pinned searches reuse `(portable profile, normalized query)` without a conflict prompt.
- User templates are local-only, freeze app-defined entries, and distinguish dynamic collection-all from explicit child identities.
- Sender actions are recommendations only; every import is validated and receiver-confirmed.
- No application-data write occurs before complete preflight and a durable rollback checkpoint.
- All user-facing text is localized through `context.t`; all Riverpod workflow state uses manually declared Notifier or AsyncNotifier providers.
- Existing ZIP and JSON formats remain import-only compatibility paths.
- Use `fvm` for Dart and Flutter commands and run `fvm dart format` after each Dart file batch.

## Review Focus

- A forged ZIP with traversal, duplicate paths, an inflated entry, or a digest mismatch must fail before source parsing (Task 3 tests).
- A repository mutation after preflight must invalidate Apply rather than execute a stale destructive plan (Task 6 tests).
- An interrupted import at every journal boundary must restore profiles, definitions, memberships, order, caches, and runtime records (Task 6 tests).
- The same post ID on two Gelbooru-compatible sites must remain two bookmarks, while two profiles for one site must share identity (Task 1 tests).
- A messaging app that strips the custom MIME type must not make Boorusama claim every octet-stream file; picker fallback must still import the package (Task 8 tests).

---

### Task 1: Portable bookmark identity

**Files:**
- Create: `lib/core/bookmarks/src/types/bookmark_identity.dart`
- Modify: `lib/core/bookmarks/src/types/bookmark.dart`
- Modify: `lib/core/bookmarks/src/data/bookmark_convert.dart`
- Modify: `lib/core/bookmarks/types.dart`
- Modify: `lib/core/backups/sources/bookmark_backup_codec.dart`
- Modify: `lib/core/backups/sources/bookmark_backup_data.dart`
- Modify: `lib/core/backups/sources/bookmark_import_planner.dart`
- Modify: `docs/bookmark_groups.md`
- Test: `test/core/bookmarks/bookmark_identity_test.dart`
- Test: `test/core/backups/bookmark_backup_codec_test.dart`
- Test: `test/core/backups/bookmark_import_planner_test.dart`

**Interfaces:**
- Produces: `BookmarkIdentity`, `BookmarkIdentity.fromPost(Post)`, `Bookmark.identity`, and version 3 bookmark payload identities used by Tasks 3–5.
- Consumes: `PostOrigin.booruType`, normalized source host, and non-null `Post.id` from the unified post model.

- [ ] **Step 1: Write failing identity tests.** Prove same engine/site/post ID matches across profiles and media URL changes; same engine/post ID on different normalized sites differs; legacy bookmark JSON still decodes.
- [ ] **Step 2: Run `fvm flutter test test/core/bookmarks/bookmark_identity_test.dart test/core/backups/bookmark_backup_codec_test.dart test/core/backups/bookmark_import_planner_test.dart`.** Expected: FAIL because post identity is not defined and current URL identity collapses the wrong cases.
- [ ] **Step 3: Implement `BookmarkIdentity` as an Equatable value with `String booruType`, `String site`, and `int postId`; normalize site with the post-origin URL helper and expose an explicit legacy URL identity only inside the legacy decoder.**
- [ ] **Step 4: Raise bookmark source schema to 3, encode identity in every new row, and make import planning match the portable identity.** Reject a new-format bookmark without post identity; keep version 1/2 parsing through the legacy adapter.
- [ ] **Step 5: Format and rerun the focused tests.** Expected: PASS.
- [ ] **Step 6: Commit.** `refactor(bookmarks): use portable post identity`

### Task 2: Selection rules, templates, and package manifest

**Files:**
- Create: `lib/core/backups/export_import/models/export_selection.dart`
- Create: `lib/core/backups/export_import/models/export_template.dart`
- Create: `lib/core/backups/export_import/models/import_action.dart`
- Create: `lib/core/backups/export_import/models/package_manifest.dart`
- Create: `lib/core/backups/export_import/template_repository.dart`
- Modify: `lib/core/backups/types/backup_data_source.dart`
- Modify: `lib/core/backups/types/backup_registry.dart`
- Test: `test/core/backups/export_import/export_selection_test.dart`
- Test: `test/core/backups/export_import/export_template_test.dart`
- Test: `test/core/backups/export_import/package_manifest_test.dart`

**Interfaces:**
- Consumes: source IDs and priorities from `BackupRegistry`.
- Produces: `ExportSelection`, `ExportNodeSelection`, `ExportTemplate`, `ImportAction`, `ExportPackageManifest`, `ExportSourceManifest`, `ExportPartManifest`, `ExportTemplateRepository`, and `BackupDataSource.selectionDescriptor` for every later task.

- [ ] **Step 1: Write failing model tests.** Cover dynamic-all versus explicit-all-current equality, future user children, frozen app nodes, Full export including a newly registered source, unknown manifest fields, and malformed relative part paths.
- [ ] **Step 2: Run the three new test files.** Expected: FAIL because the contracts do not exist.
- [ ] **Step 3: Implement immutable Equatable selection/action/manifest models with defensive nullable JSON parsing.** `ExportSelection.full(registry)` is evaluated against the live registry; templates serialize exact app-node IDs and selection kinds.
- [ ] **Step 4: Implement `ExportTemplateRepository` over the existing settings Hive box under `export_import:templates`, including save, replace, delete, and ordered load.** Templates contain no exported payload.
- [ ] **Step 5: Add source selection descriptors to the registry contract without adding UI logic to sources.** Existing sources initially expose a single leaf; collection sources gain children in Task 4.
- [ ] **Step 6: Format and rerun focused tests.** Expected: PASS.
- [ ] **Step 7: Commit.** `feat(backups): define export package contracts`

### Task 3: Safe streaming `.bsexport` container

**Files:**
- Create: `lib/core/backups/export_import/package/export_package_reader.dart`
- Create: `lib/core/backups/export_import/package/export_package_writer.dart`
- Create: `lib/core/backups/export_import/package/export_package_limits.dart`
- Create: `lib/core/backups/export_import/package/export_package_exception.dart`
- Create: `lib/core/backups/export_import/package/staged_export_package.dart`
- Modify: `lib/core/backups/zip/bulk_backup_service.dart`
- Test: `test/core/backups/export_import/export_package_reader_test.dart`
- Test: `test/core/backups/export_import/export_package_writer_test.dart`
- Test: `test/core/backups/export_import/export_package_memory_test.dart`

**Interfaces:**
- Consumes: Task 2 manifest models and `AppFileSystem`.
- Produces: `ExportPackageWriter.write(ExportPackageBuild)`, `ExportPackageReader.stage(String)`, `StagedExportPackage`, verified staged part paths, and bounded `ExportPackageLimits` for Tasks 5–9.

- [ ] **Step 1: Write failing writer/reader tests.** Assert atomic `.tmp` rename, SHA-256 and byte lengths, no final file after a source failure, custom extension, traversal/absolute/duplicate path rejection, digest mismatch, encrypted/unsupported entries, file-count and expansion limits.
- [ ] **Step 2: Run the new reader/writer tests.** Expected: FAIL because package I/O does not exist.
- [ ] **Step 3: Implement the writer with source payload temp files and `ZipFileEncoder.addFile`; write `manifest.json` last and rename the completed temp archive atomically.**
- [ ] **Step 4: Implement the reader with `InputFileStream`, metadata validation before extraction, bounded streaming extraction to app-private staging, digest verification during/after each part, and staged cleanup ownership.** Never call `readBytes` on the entire package.
- [ ] **Step 5: Add a generated 50 MiB bookmark fixture memory test with a fixed peak allowance and prove the writer/reader do not scale by full archive size.**
- [ ] **Step 6: Format and rerun all Task 3 tests.** Expected: PASS.
- [ ] **Step 7: Commit.** `feat(backups): add safe bsexport container`

### Task 4: Export source adapters and credential control

**Files:**
- Create: `lib/core/backups/export_import/sources/export_import_source.dart`
- Create: `lib/core/backups/export_import/sources/legacy_json_source_adapter.dart`
- Create: `lib/core/backups/export_import/sources/profile_export_sanitizer.dart`
- Create: `lib/core/backups/export_import/export/export_service.dart`
- Modify: `lib/core/backups/sources/providers.dart`
- Modify: `lib/core/backups/sources/booru_configs_source.dart`
- Modify: `lib/core/backups/sources/bookmarks_source.dart`
- Modify: `lib/core/backups/sources/pinned_searches_source.dart`
- Modify: `lib/core/backups/sources/following_feeds_source.dart`
- Modify: other registered source files under `lib/core/backups/sources/`
- Test: `test/core/backups/export_import/profile_export_sanitizer_test.dart`
- Test: `test/core/backups/export_import/export_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3 contracts and existing codecs/data getters.
- Produces: `ExportImportSource`, `ExportSourceSnapshot`, `ExportService.createPackage(ExportRequest)`, per-source selection descriptors, and sanitized profile payloads for Tasks 5–9.

- [ ] **Step 1: Write failing sanitizer and export-service tests.** Full export includes every registered source and credentials; custom export strips API key, login, pass hash, proxy username/password, and engine auth fields; selected-source failure leaves no package; bookmark group/No group, folders/searches, feeds, and profiles filter correctly.
- [ ] **Step 2: Run the focused tests.** Expected: FAIL because adapters and sanitization do not exist.
- [ ] **Step 3: Implement the source contract:** `capture(ExportSourceRequest)`, `decode(StagedSourcePayload)`, `validate`, `snapshotForRollback`, `plan`, `apply`, and `restore`, plus localized selection metadata supplied outside widgets.
- [ ] **Step 4: Bridge every existing source codec to package payload files.** JSON remains internal to the container; remove source-level JSON and clipboard actions from new UI without deleting legacy decoders.
- [ ] **Step 5: Implement a typed profile sanitizer before JSON encoding.** A credential-free update marker tells Task 5 to preserve existing credentials on matches.
- [ ] **Step 6: Implement `ExportService` so Full resolves the live registry, captures all selected source snapshots, and delegates atomic package output to Task 3.**
- [ ] **Step 7: Format and rerun focused plus existing source codec tests.** Expected: PASS.
- [ ] **Step 8: Commit.** `feat(backups): export sources through bsexport`

### Task 5: Collection import planning and profile mapping

**Files:**
- Create: `lib/core/backups/export_import/import/import_plan.dart`
- Create: `lib/core/backups/export_import/import/import_planner.dart`
- Create: `lib/core/backups/export_import/import/profile_mapping.dart`
- Modify: `lib/core/backups/sources/bookmark_import_plan.dart`
- Modify: `lib/core/backups/sources/bookmark_import_planner.dart`
- Modify: `lib/core/backups/sources/bookmark_import_service.dart`
- Modify: `lib/core/backups/sources/pinned_search_import_service.dart`
- Modify: `lib/core/backups/sources/following_feed_import_service.dart`
- Modify: `lib/core/search/subscriptions/src/types/search_organization.dart`
- Test: `test/core/backups/export_import/import_planner_test.dart`
- Test: `test/core/backups/bookmark_import_service_test.dart`
- Test: `test/core/backups/pinned_search_import_service_test.dart`
- Test: `test/core/backups/following_feed_import_service_test.dart`

**Interfaces:**
- Consumes: decoded source snapshots, `ImportAction`, Task 1 identities, current repository snapshots, and source selection completeness.
- Produces: immutable `ProposedImportPlan`, `ResolvedImportPlan`, item action availability, `ProfileMapping`, planned-change counts, warnings, errors, and source apply payloads for Task 6 and UI.

- [ ] **Step 1: Write failing planner tests.** Cover legal whole-source Replace/Skip; complete-only category Replace; same UUID default Update; conditional Merge into target; Copy UUID; sender recommendations as editable defaults; identical pins silently reused; single profile auto-map and ambiguous/missing errors.
- [ ] **Step 2: Add failing collection-service tests.** Bookmark Update mirrors membership and deletes only newly orphaned bookmarks; Merge retains local-only membership/name; folder Update/Merge preserves defined order; feed Update/Merge preserves shared internal search runtime state.
- [ ] **Step 3: Run all Task 5 tests.** Expected: FAIL on missing actions and orphan behavior.
- [ ] **Step 4: Implement the generic immutable planner and profile mapper.** Unsupported recommendations fall back to the first safe applicable action and produce a warning; they never skip validation.
- [ ] **Step 5: Extend bookmark, pinned-search organization, and feed services with explicit Update, Merge, Merge into target, Copy, and Skip apply payloads.** Keep source business rules in services, not UI.
- [ ] **Step 6: Format and rerun Task 5 plus existing bookmark/search backup tests.** Expected: PASS.
- [ ] **Step 7: Commit.** `feat(backups): plan collection import actions`

### Task 6: Comprehensive preflight and durable rollback

**Files:**
- Create: `lib/core/backups/export_import/import/import_preflight.dart`
- Create: `lib/core/backups/export_import/import/import_transaction.dart`
- Create: `lib/core/backups/export_import/import/import_journal.dart`
- Create: `lib/core/backups/export_import/import/import_recovery_service.dart`
- Create: `lib/core/backups/export_import/import/import_coordinator.dart`
- Modify: app startup provider wiring under `lib/core/`
- Test: `test/core/backups/export_import/import_preflight_test.dart`
- Test: `test/core/backups/export_import/import_transaction_test.dart`
- Test: `test/core/backups/export_import/import_recovery_test.dart`

**Interfaces:**
- Consumes: Tasks 3–5 staged package, resolved plan, source adapters, repository revision tokens, and `AppFileSystem`.
- Produces: `ImportPreflightResult`, `ValidatedImportPlan`, `ImportCoordinator.prepare/apply`, durable journal states, reverse restore, and startup `ImportRecoveryService.recoverPending()` for Tasks 7–9.

- [ ] **Step 1: Write failing preflight tests.** Cover all spec checks, concise clean result, warning acknowledgement, unresolved dependencies, insufficient staging/rollback space, illegal target, and stale repository revision.
- [ ] **Step 2: Write failure-injection transaction tests.** For every source step and journal boundary, assert old state is restored in reverse order; rollback failure retains the journal and blocks affected mutation; a successful transaction removes it.
- [ ] **Step 3: Run all Task 6 tests.** Expected: FAIL because package-level transaction/recovery does not exist.
- [ ] **Step 4: Implement preflight as a pure aggregation over source validation and planning results.** It returns errors, warnings, exact planned changes, and revision tokens without mutating repositories.
- [ ] **Step 5: Implement durable transaction directory and fsynced journal transitions: prepared, applying source, applied source, rolling back, recovered, committed.** Store hashed plan and rollback payloads before the first app-data write.
- [ ] **Step 6: Implement coordinator serialization, revision recheck, dependency-order apply, reverse rollback, and startup recovery.** Defer provider/app restart until journal commit.
- [ ] **Step 7: Format and rerun Task 6 tests.** Expected: PASS.
- [ ] **Step 8: Commit.** `feat(backups): apply imports with durable rollback`

### Task 7: Unified export/import UI, templates, and clipboard

**Files:**
- Create: `lib/core/backups/export_import/export/export_flow_notifier.dart`
- Create: `lib/core/backups/export_import/export/export_flow_page.dart`
- Create: `lib/core/backups/export_import/import/import_flow_notifier.dart`
- Create: `lib/core/backups/export_import/import/import_flow_page.dart`
- Create: `lib/core/backups/export_import/widgets/selection_tree.dart`
- Create: `lib/core/backups/export_import/widgets/import_action_editor.dart`
- Create: `lib/core/backups/export_import/clipboard/export_clipboard_service.dart`
- Modify: `lib/core/backups/widgets/backup_settings_section.dart`
- Modify: `lib/core/backups/routes.dart`
- Modify: `lib/foundation/clipboard.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/backups/export_import/export_flow_page_test.dart`
- Test: `test/core/backups/export_import/import_flow_page_test.dart`
- Test: `test/core/backups/export_import/export_clipboard_service_test.dart`

**Interfaces:**
- Consumes: Tasks 2–6 service APIs and results.
- Produces: the approved visible flows, manually declared Notifier state, package Save/Share/Base64 actions, local template management, and clipboard import for Task 8 entry routing.

- [ ] **Step 1: Write failing widget tests for Full and custom export.** Assert Full has credentials enabled without a profile checkbox, private confirmation gates creation, expandable tri-state trees preserve semantic selection, templates Save only/Save & export, and Save/Share always remain available.
- [ ] **Step 2: Write failing import widget tests.** Assert picker precedes review, actions appear only when applicable, same UUID defaults Update, identical pins only affect info count, one profile auto-maps, clean preflight says All checks passed, and error/warning details gate Apply.
- [ ] **Step 3: Write failing clipboard tests.** Assert exact Base64 round trip with custom type, proactive metadata-only detection, payload read only after tap, 1 MiB/credential rejection, and undetected text fallback.
- [ ] **Step 4: Run Task 7 tests.** Expected: FAIL because the unified pages and clipboard service do not exist.
- [ ] **Step 5: Implement export and import Notifiers with immutable step state; implement pages/widgets to match the approved mockup using only localized strings.**
- [ ] **Step 6: Implement platform-channel clipboard custom-type read/write with plain-text version prefix fallback.** Keep the existing ordinary text/image clipboard methods intact.
- [ ] **Step 7: Replace the old settings cards with one Export & import entry while leaving legacy imports reachable through detected old files.**
- [ ] **Step 8: Run `./gen.sh`, format, and rerun Task 7 tests.** Expected: PASS.
- [ ] **Step 9: Commit.** `feat(backups): add unified export import flows`

### Task 8: File associations, received files, and sharing

**Files:**
- Create: `lib/core/backups/export_import/platform/received_export_service.dart`
- Create or modify: `android/app/src/main/kotlin/.../MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `macos/Runner/Info.plist`
- Modify: desktop runner registration files where supported
- Modify: `lib/main.dart` or application route bootstrap
- Test: `test/core/backups/export_import/received_export_service_test.dart`
- Test: `test/core/backups/export_import/file_type_configuration_test.dart`

**Interfaces:**
- Consumes: Task 3 reader, Task 7 import route, platform `content:`/document URLs, and `share_plus`.
- Produces: cold/warm received-file streams, private staged copies, Save/Share actions with the custom MIME type, and route queuing until Flutter navigation is ready.

- [ ] **Step 1: Write failing service/configuration tests.** Assert cold and warm events deduplicate, received bytes are copied before transient access ends, only custom MIME is registered, Android does not claim all octet streams, and extension picker fallback still validates content.
- [ ] **Step 2: Run Task 8 tests.** Expected: FAIL because file-type routing is absent.
- [ ] **Step 3: Implement Android `ACTION_VIEW`/`ACTION_SEND` custom-MIME handling for `content:` URIs in cold start and `singleTop` `onNewIntent`; bridge streams through an EventChannel/MethodChannel.**
- [ ] **Step 4: Register Apple exported UTI/document types conforming to `public.content` and `public.data`, and route incoming document URLs through the same service.**
- [ ] **Step 5: Implement received-file staging and navigation queue plus Share action MIME/filename.** Do not trust extension or intent MIME after reception; Task 3 validates the bytes.
- [ ] **Step 6: Format and rerun Task 8 tests.** Expected: PASS.
- [ ] **Step 7: Commit.** `feat(backups): open bsexport files from the system`

### Task 9: Automatic export, nearby transfer, compatibility, and final validation

**Files:**
- Modify: `lib/core/backups/auto/service.dart`
- Modify: `lib/core/backups/auto/repo.dart`
- Modify: `lib/core/backups/auto/repo_io.dart`
- Modify: `lib/core/backups/auto/types.dart`
- Modify: `lib/core/backups/transfer/export/export_data_notifier.dart`
- Modify: `lib/core/backups/transfer/import/import_data_notifier.dart`
- Modify: `lib/core/backups/servers/server.dart`
- Modify: `lib/core/backups/zip/backup_notifier.dart`
- Modify: `docs/bookmark_groups.md`
- Modify: `docs/pinned_searches.md`
- Modify: `docs/work/in-progress/DATA-001-unified-export-import.md`
- Test: existing and new tests under `test/core/backups/`

**Interfaces:**
- Consumes: Tasks 3–8 end-to-end export/import coordinator.
- Produces: Full automatic `.bsexport`, one-package nearby transfer, legacy sniff/import adapters, removed legacy output UI, completed docs and validation evidence.

- [ ] **Step 1: Write failing integration tests.** Automatic export includes every current source/credentials and tracks `.zip` plus `.bsexport` retention; nearby transfer sends one package; legacy ZIP/JSON sniffing enters the new plan; no public path creates JSON or legacy ZIP.
- [ ] **Step 2: Run the integration tests.** Expected: FAIL while old services still create ZIP/source endpoints.
- [ ] **Step 3: Route automatic and nearby export/import through `ExportService` and `ImportCoordinator`; keep old decoders behind import-only sniffing.** Update retention enumeration to both extensions.
- [ ] **Step 4: Remove old user-facing source file/clipboard and bulk ZIP output actions after all callers have migrated.** Preserve source codecs and legacy import tests.
- [ ] **Step 5: Run `./gen.sh`, `fvm dart format` on changed Dart files, focused backup tests, `fvm flutter test`, `fvm flutter analyze`, and `git diff --check`.** Expected: all exit 0.
- [ ] **Step 6: Build/install the development Android app and use Maestro to verify Full export, custom group export, template reuse, file-picker import, applicable Update/Merge choices, preflight, and a safe confirmed import.** Record screenshots/results without credentials.
- [ ] **Step 7: Update subsystem docs and the work item with exact evidence; move the work item to `docs/work/done/` only when every acceptance criterion is verified.**
- [ ] **Step 8: Commit.** `feat(backups): complete unified export import migration`
