# Stage 02: unified Bookmark storage and v10 migration

**Issue:** #155. **Branch:** `maintenance/155-unified-bookmark-storage`.
**Base:** reviewed #154 candidate including the verified #132 prerequisite.
**Goal:** one ID/membership/mutation system for all saved content, with a lossless, recoverable local migration and v10 backup support.
**Specification:** [approved contract](approved-contract.md), especially sections 7-8. **Final reviewer:** independent Astra High.

This is one cohesive storage cutover. Frequent intermediate commits are encouraged, but no intermediate release may expose two allocators or partially migrated memberships. Run the common test/review loop for every task below.

## Source map

Inspect and adapt:
- `lib/core/bookmarks/src/types/bookmark.dart`, `bookmark_identity.dart`, `bookmark_group.dart`, `bookmark_library_state.dart`, `bookmark_repository.dart`, `pool_bookmark.dart`, `pool_bookmark_cover.dart`, `pool_bookmark_repository.dart`, `bookmark_grid_entry.dart`, `bookmark_target.dart`, `bookmark_picker_request.dart`.
- `lib/core/bookmarks/src/data/hive/repository.dart`, `bookmark_hive_object.dart`, `bookmark_group_repository_hive.dart`, `bookmark_group_hive_object.dart`, data providers and converters.
- `lib/core/bookmarks/src/services/bookmark_library_service.dart`, `bookmark_mutation_repository.dart`, bookmark providers, selectors, membership controllers and all Undo/removal consumers.
- `lib/core/backups/sources/bookmark_backup_codec.dart`, `bookmark_backup_data.dart`, `bookmarks_source.dart` and existing bookmark import/export helpers.
- `lib/core/backups/export_import/import/`: `bookmark_profile_dependency.dart`, `import_preflight.dart`, `import_transaction.dart`, `import_journal.dart`, `import_recovery_gate.dart`, `import_source_integrity_validator.dart`, `import_planned_change_projector.dart` and selected-source wrappers.
- Existing bookmark/filter/backup/Undo/favorites-sync tests and `benchmark/` snapshot/library workloads.

Proposed new files: `types/post_bookmark.dart`, `types/content_group_bookmark.dart`, `types/stored_group_snapshot.dart`, `data/stored_group_codec.dart`, `data/bookmark_id_allocator.dart`, `data/hive/unified_bookmark_repository.dart`, `services/bookmark_storage_migration.dart`. Reuse or split current files when clearer; do not create another long-lived library cache.

New tests: `test/core/bookmarks/bookmark_unified_repository_test.dart`, `bookmark_id_allocator_test.dart`, `bookmark_storage_migration_test.dart`, `related_bookmark_order_test.dart`, `stored_group_snapshot_test.dart`, and corresponding v10 tests under the existing backup test root.

## Task 1: pin current behavior before renaming

**Consumes:** existing Post/Collection records and v4-v9 fixtures. **Produces:** regression fixtures and an inventory of every writer/reader to be moved.

1. Locate all references to `Bookmark`, `.post`, `CollectionBookmark`, `PoolBookmark`, `groupIds`, `addedAt`, Hive `.add`/`.addAll`, import insertion, restore, duplicate-group and direct favorite projection. Record relevant paths in the task handoff, not a new tracker.
2. Pin loaded/cold equality, stable Post IDs including 0, Default UUID, All-as-view, per-group timestamps, last-membership deletion, multi-group Undo and incremental small mutations.
3. Include a mixed fixture with a Post in two groups, a Pool in two groups, a Related family, nested folders, restricted cover policy, incomplete tags and a legacy Post lacking stable identity.
4. Assert #132 target reassignment preserves this fixture and performs no network fetch. Commit the tests before the storage cutover.

## Task 2: rename the Post-specific model and generalize membership

**Produces:** ID-only Bookmark interface, PostBookmark, ContentGroupBookmark, RelatedBookmark; one BookmarkGroup membership contract.

1. Rename the existing concrete Bookmark to PostBookmark, preserving all current accessors/decoded snapshot caching and data fields. Do not rewrite StoredPostSnapshot wire data.
2. Add the common `abstract interface class Bookmark { int get id; }`. Update media-only consumers to explicitly consume PostBookmark; general membership/remove/picker/selection consumers use Bookmark or IDs. A temporary compatibility adapter must be private and removed at cutover, not a permanent misleading typedef.
3. Build ContentGroupBookmark from StoredGroupSnapshot and local timestamps. Derive reference/summary rather than storing duplicate identity. RelatedBookmark alone adds nullable preferredOrder and validates a Danbooru Related reference.
4. Generalize library indexes and group mutations. BookmarkGroup.bookmarkIds/addedAt are the sole membership authority; derive reverse indexes. Preserve membership dates when adding a repeat, moving/duplicating groups, updating metadata and undoing removal. Preserve each group's independent date.
5. Preserve selection identity, Recent groups, pickers, frozen action targets, sync-status exclusions, source filters, Group count cards and existing non-media states. Never cast all saved entries to Posts.
6. Keep hashed equality, write-through deltas and ambiguous-write invalidation. Tests must prove a single new membership/favorite projection does not decode the complete library. Commit.

## Task 3: Group snapshots without eager downloads

**Produces:** StoredGroupCodec and GroupBookmarkIndex.

1. Store Summary plus already loaded export-safe Details, serializing Summary once. Saving a list card must call zero detail/member/media fetches. Already loaded description/tags/creators must survive an offline roundtrip.
2. Preserve source-owned tags separately from indexed member unions, coverage, oldest/newest member upload bounds and non-secret coverPolicy. Unknown upload/count/rating remains unknown. Do not turn incomplete aggregates into authoritative source facts.
3. Exclude member manifests, live cursors, all Page snapshots, tokens, profile objects and current-account favorite state. Test nested dynamic Hive maps, malformed maps, mismatched Group identity and unknown typed payload versions.
4. Preserve good cached Details on a Summary-only refresh; authoritative engine updates may remove known metadata. Failed refresh must not advance observedAt. Snapshot update must preserve Related order and memberships.
5. Keep existing Post UnknownPostData/legacy behavior. New unsupported Group structure fails preflight before any write. A supported record with no available network reader is not structurally invalid.

## Task 4: one durable ID namespace

**Produces:** central allocation and a single repository facade; existing raw Post/Group payload stores may remain private.

1. Reserve nonnegative integer IDs above the current durable high-water mark, including existing Post keys. Persist and sync reservation before exposing IDs. Gaps are allowed; recycling is forbidden. Respect actual storage/target integer limits and fail cleanly on exhaustion.
2. Give the facade an authoritative ID-to-kind lookup. Generic read/delete dispatches by that index, not numeric ranges or payload guessing. Incompatible ID collisions fail validation.
3. Switch all autonomous Post create/import/restore writers from Box.add/addAll together. Internal stores receive already reserved explicit keys. Include server favorites, recovery of incomplete snapshots, bulk imports and Undo recreation.
4. Serialize allocation and multi-record mutations with the existing data mutation coordinator; avoid nested lock deadlock. Recovery must handle failure before reservation sync, after reservation, after payload write and commit-then-throw ambiguity.
5. Tests concurrently reserve/save Posts and Groups; restart between reservations; import high/low file-local IDs; delete/undo; fail a durable write. No path may reuse an issued ID, lower the counter or expose a kind index without its payload.

## Task 5: crash-recoverable local migration

**Consumes:** v9-era local Post and Collection layouts. **Produces:** one active local schema, unchanged Post IDs, mapped Group IDs and complete recovery evidence.

1. Preflight all source records and revisions. Preserve unknown legacy Post payloads. Do not guess aliases, engines or historical transport schemes. Keep the original legacy source evidence; unresolved network access must never cause a saved record to disappear.
2. Assign one new int for each old Collection UUID; preserve its identity, cached metadata and every group/date pair. Do not use `DateTime.now()` for known historical dates. Preserve all local Group UUIDs/folder placement and Default rules.
3. Persist the mapping and recovery plan durably. Stage new Group payloads and unified memberships, validate counts/IDs/date equality, then durably activate the new local schema/generation. Do not retire the old authority before activation succeeds.
4. Reuse the existing import journal/revision/hash/recovery pattern. If multi-box writes cannot be atomic, use staging plus an explicit activation marker and startup recovery gate. A try/catch restoring RAM is not sufficient.
5. Inject interruption before/after each durable boundary. Fresh startup must resume deterministically or restore/block editing with a recoverable explanation. Never show a partly writable library. Re-running migration must not create new mappings or duplicate entries.
6. Preserve legacy data when preflight fails. A detected incompatible identity conflict requires a non-destructive report, not silently merging snapshots. #43 alias reconciliation is not performed here.

## Task 6: v10 backup/import and all shared transfer paths

1. Keep the .bsexport container and v4-v9 readers. The bookmark section writes one tagged array of post/group/related records, file-local ints and unified memberships/dates. Common Group snapshot version 1 and local storage schema are independent of backup 10.
2. Map imported IDs to existing/new local IDs through validated compatible identity. Importing localId 7 does not overwrite unrelated local record 7. Preserve legacy v9 createdAt reconstruction rather than inventing original history.
3. Test Merge, Merge Into, Update, Replace, duplicated Groups, selected folders, export templates, clipboard/nearby transfers and full-backup restore through their shared planner/codec. Old paths must not keep exporting a second Collection array as the authoritative format.
4. Reject malformed or unsupported structural versions and new Group keys/payloads in preflight before changing any selected source. Preserve supported-but-inaccessible content. Keep existing Post unknown-custom-data behavior unchanged.
5. Include snapshot/metadata privacy checks, credential exclusion, source-profile hint non-authority, dates, cover/index, Related order and Group/Page independence. Failed import must recover through the existing durable journal.
6. Existing profile-dependency gate may remain in this stage; #142 removes it next. Do not implement profileless reads or alias migration as an undocumented side effect.

## Task 7: Related-only order and legacy callers

1. Capture visible oldest/newest on first Related save; opening a saved family uses its own nullable preference, otherwise global fallback. Explicit change updates only that family, not every saved group.
2. Preserve preference during refresh, import/export, copy membership, duplicate group and Undo. Never store a fixed member-ID list to express direction.
3. Keep existing Related grid/timeline UI. Adapt its order provider/picker bridge to the new record without adding a media-first viewer, generic viewOptions or manual ordering.
4. Keep legacy Pool/Related UI functioning through thin adapters until #156. New storage cannot require that later UI stage to compile or preserve current behavior.

## Exit gate and delegation

Run all bookmark and backup/import/export suites, related/selection/Favorites Sync consumers, format and analysis, then the complete repository regression. Use fault-injected persistence tests and a leased Android upgrade scenario with a disposable representative pre-migration database; export a recovery backup first. Verify cold restart, v9 import and v10 roundtrip. Do not run destructive upgrade tests against the user's real library.

Lower-cost agents may inventory callers, add safe fixture variants, perform approved mechanical PostBookmark renames in disjoint files, or update localized type-neutral labels. They must not choose migration policy, allocator semantics, source authorization or merge conflicts in shared writers. The lead owns those areas. Independent Astra High reviews the entire cutover, with particular attention to legacy unaddressable Posts, commit-then-throw failures, two-box activation, membership timestamps, unknown Group versions and all hidden import/Undo writers.

Do not move to #142 until required tests and the independent final review pass. A storage-only source review without FVM and restart tests is not a ready candidate. Deliver an issue-specific handoff and leave the issue open pending authorized publication.
