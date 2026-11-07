# Stage 02a: unified local Bookmark hierarchy (#158)

Implement after the verified #155 runtime, before the existing stage 03 / #142. Read the [approved hierarchy specification](../../designs/2026-11-07-bookmark-group-hierarchy.md) and [handoff](../../handoffs/158-bookmark-hierarchy-insertion.md). This is an execution plan, not a second issue/status tracker.

## Base and changed rollout order

Issue: [#158](https://github.com/timberpile/Boorusama/issues/158).
Branch: `feature/158-unified-bookmark-hierarchy`.
Pinned parent: `f6deb27590a38a812c532c939085742886cdda3f` on `maintenance/155-unified-bookmark-storage`.
Runtime candidate inherited from #155: `6b390c611b5dc4b4dcf8356172635fd698356678`.

The [new #155 handoff](../../handoffs/155-unified-bookmark-storage.md) reports a completed full regression and final independent Astra High re-review. Do not rerun its completed implementation sequence or treat old source inspection as proof of missing unified storage. Its pause before #142 is superseded by the user's explicit request to implement this insert and then continue the rest of the rollout, not by permission to integrate or publish runtime changes.

Sequence: preserve #132/#154/#155 -> **#158** -> #142 -> #143 -> #156 -> #140 -> #141 -> #157 -> final cross-stage review. #153 remains separately scoped. The planning baseline is `fdb68f657284e1f76701c83683aa0228484d09c8`; read its `docs/plans/content-architecture/README.md` and remaining numbered plans through `git show` or a read-only reference worktree. They are not all present on this task branch.

## Phase A. Establish the exact starting point

Read current `AGENTS.md`, `.agents/skills/execute-plan/SKILL.md`, `docs/issue_workflow.md`, relevant development/engineering guidance, `docs/ui_style_guide.md`, and the live issue/comments. Inspect local branches, worktrees, outgoing commits, and any unfinished #155 work. Reuse an existing #158 worktree or attach the already published branch in a new isolated worktree. Never reset/stash/switch the user's primary checkout or recreate the branch from develop.

Record the actual base and candidate SHA in the normal handoff. Validate that the parent runtime matches the #155 evidence before reusing it. Preserve any newer legitimate #155 fixes and agree their propagation with the current owner. Do not overwrite the original #155 handoff with a fictional #158 approval.

Inspect these existing boundaries before changing code:

| Boundary | Existing paths at the pinned base |
| --- | --- |
| Canonical records/indexes | `lib/core/bookmarks/src/types/bookmark.dart`, `post_bookmark.dart`, `content_group_bookmark.dart`, `legacy_group_bookmark.dart`, `bookmark_library_state.dart`, `bookmark_record_index.dart` |
| Membership and hierarchy | `lib/core/bookmarks/src/types/bookmark_group.dart`, `bookmark_view.dart`, `bookmark_target.dart`, `lib/core/groups/folder_tree.dart` |
| Organization persistence | `lib/core/bookmarks/src/data/hive/unified_bookmark_repository.dart`, `unified_bookmark_organization.dart`, `unified_bookmark_group_repository.dart`, `bookmark_group_hive_object.dart` |
| Migration/mutations | `lib/core/bookmarks/src/services/bookmark_storage_migration.dart`, `bookmark_library_service.dart`, `bookmark_library_records.dart`, `bookmark_mutation_repository.dart`, `lib/foundation/data_mutation_coordinator.dart` |
| Transfer | `lib/core/backups/sources/bookmark_backup_codec.dart`, `bookmark_backup_data.dart`, `bookmark_unified_import.dart`, `bookmark_import_planner.dart`, `bookmark_import_service.dart`, `bookmarks_source.dart`, and `lib/core/backups/export_import/` consumers |
| Browser/query | `lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`, `bookmark_page.dart`, `lib/core/bookmarks/src/providers/bookmark_group_selectors.dart`, `lib/core/bookmarks/src/data/bookmark_view_refresh_gate.dart` |
| Timeline/search | `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`, `bookmark_search_bar.dart`, `bookmark_list_controls.dart`, `bookmark_appbar.dart`; tag-index and suggestion providers |
| Picker | `lib/core/bookmarks/src/widgets/bookmark_group_picker.dart`, `bookmark_folder_picker_contents.dart`, `bookmark_picker_group_creation.dart`, `bookmark_batch_dialog.dart`; `bookmark_picker_actions.dart`, `bookmark_picker_request.dart`, Recent and sync-target consumers |
| Scroll infrastructure | `lib/core/posts/listing/src/widgets/timeline_header_sliver.dart`, `measured_floating_header.dart`, `post_grid.dart`, `lib/core/posts/listing/src/_internal/raw_post_grid.dart` |

Resolve moved paths explicitly; do not add duplicate classes merely because a plan uses a conceptual name. Inspect code before assuming subsystem documentation is current: `docs/bookmark_groups.md` still contains older active-group and pre-v10 descriptions at this baseline.

## Phase B. Hierarchy model and validation

Start with failing tests for conversion and tree invariants. Adapt `BookmarkGroup` to `parentGroupId`, keeping direct membership IDs/dates and existing Default identity. Add an immutable indexed tree or narrowly reuse appropriate existing traversal logic. Do not change unrelated Following folder behavior.

Cover empty groups, root/child placement, duplicate display names, parent/group ID collisions in legacy input, missing parents, cycles, deep iterative traversal, moves into descendants, and stable sibling ordering. Preserve existing group UUIDs and all Bookmark integer IDs. No source references or Post snapshots are rewritten to perform organization changes.

Adapt library committed-delta publication and membership selectors to the unified group forest. Remove separate Bookmark folder authority at the canonical boundary; compatibility decoding may still use legacy DTOs. Keep `applyCommittedChanges` incremental and avoid decoding every payload for a rename or one membership toggle.

Gate: tree/model tests and existing library/index/date tests pass; invalid operations are rejected before any storage write.

## Phase C. Recoverable organization migration and transfer

Extend #155's durable migration/journal, not a second unrelated startup migration service. Preserve old v2 generation evidence. Define a new explicit hierarchy generation, with an active marker and staged contents that older code cannot misinterpret as v2.

Handle both entry paths:

1. Legacy Post/folder/Collection storage, including an interrupted #155 migration.
2. Already active unified-v2 storage with real subsequent writes, allocator reservations, tombstones, Default placement, loaded Details and Related order.

Resolve pending journals before planning the next generation. Persist collision maps before use. Inject interruption after each durable boundary, reopen and compare semantic state. Do not allocate new Bookmark IDs just to convert folders; only local group UUID collisions need remapping. Never lower or reconstruct the allocator from imported IDs.

Add hierarchy backup writer v11 and keep v4-v10 readers plus v11. This is intentional: v10 already exists on #155 and cannot silently acquire parent semantics an older reader ignores. Adapt source version metadata, previews, custom scope/tree selection, templates, dependency checks, conflict normalization, merge/update/copy/full replace, cancellation, durability and restart recovery. Validated parent graphs must be identical in preview and apply. Keep normal per-group update direct rather than recursive. Explicit subtree export retains separate group definitions and empty structural nodes.

Test duplicate names, cross-namespace UUID collisions, Default, legacy folder selection aliases, a selected child without its full parent selection, external transfer-ID remapping, unknown formats, and profile-hint neutrality. Preserve unaddressable Posts and opaque legacy Collections; the exact identity-collapse fix in #155 must remain covered. The profile-independent-import feature itself remains stage #142.

Observed predecessor suites to retain include:

- `test/core/bookmarks/bookmark_storage_migration_test.dart`
- `test/core/bookmarks/bookmark_storage_preservation_test.dart`
- `test/core/bookmarks/bookmark_unified_organization_test.dart`
- `test/core/bookmarks/bookmark_unified_repository_test.dart`
- `test/core/bookmarks/bookmark_id_allocator_test.dart`
- `test/core/backups/bookmark_backup_v10_test.dart`
- `test/core/backups/bookmark_unified_import_test.dart`
- `test/core/backups/bookmark_unified_import_recovery_test.dart`
- `test/core/backups/export_import/bookmark_profile_hint_identity_test.dart`

Do not delete v10 fixtures or change them all to v11: they are compatibility evidence. Add distinct v11 hierarchy fixtures and cold-reopen tests.

Gate: deterministic preflight, migration/recovery and transfer tests pass before production UI consumes the new store. No partially migrated writable state is allowed.

## Phase D. Direct/subtree read models and mutations

Extend validated `BookmarkView` with subtree scope while keeping `.group(id)` direct and `.all()` library-wide. Build a deduplicated local-ID projection using #155's canonical `byId` and direct membership indexes. Use one hierarchy adjacency index per relevant snapshot, with lifecycle-scoped caches rather than all-pairs descendant unions.

Thread the scope through grid entries, tag index/autocomplete, count, source filter, sorting, shuffle, refresh invalidation, viewer entry mapping and action snapshots. Verify mixed Posts/native Groups/Related/legacy records, no profile, and unaddressable saved records. Do not infer an identity for deduplication; the local record ID already supplies it.

A subtree's newest/oldest membership sort considers only dates inside that subtree. Moving a group invalidates old and new ancestor views but does not mutate membership timestamps. Ordinary child-card order is independent of a content filter/query.

Adapt direct writes, rename, move, duplicate, delete preview and Undo. Default deletion protection remains. Deleting a non-leaf group preserves/promotes its children by default; its own direct memberships follow the existing explicit deletion/orphan policy. Prevent duplicated work for ancestor-plus-descendant selections. Aggregate removal/move asks for actual source membership(s), never globally deletes because the parent lacks direct membership.

Implement per-group mode persistence using existing local settings. Exclude the map from backups and sync. Hide the mode switch when no children exist without discarding its saved value. Query/selection/scroll keys include group and scope as specified.

Gate: queries, indexes, direct-vs-subtree operations, Undo races, and local preference roundtrip tests pass. Browsing or changing mode does not trigger remote metadata/member loads.

## Phase E. One screen and the section-boundary scroll prototype

First build a focused widget test harness using the production timeline slivers with a nontrivial preceding child-card section, not a second imitation renderer. Reproduce these positions: top; downward hidden controls; deep upward reveal; continued upward through the card/timeline boundary; top restored. Assert geometry and hit testing, not only widget existence.

Only then compose the unified production Group screen. Retain Kurumi Header title fitting and safe-area ownership. Add ancestor navigation on the clickable title and the Header-only mode control; remove the browser's name filter and permanent breadcrumbs. Do not add an extra segmented-control row.

Structure uses one scroll controller and lazy child-card slivers before the existing direct Bookmark search/toolbar and grid. The cards remain visible/unfiltered when direct content has no query matches. All Bookmarks omits the cards and uses the subtree timeline. Retain controls for a filtered zero-result state. A genuinely empty direct-membership section may show a compact empty state without an unusable toolbar.

Use the existing opaque semantic surface and rounded search field. Preserve search/toolbar visibility settings, reduced motion, selection surfaces, pull-to-refresh and the active viewer's return mapping. Avoid toolbar duplication, hard-coded section heights and broad scroll/framework refactors. If the production floating header needs correction, constrain it to its section and run every relevant existing timeline consumer test.

Test dynamic chip wrapping, text scaling, narrow width, keyboard/IME, portrait/landscape, a child inserted/removed while scrolled, a short/no-results timeline, and restored navigation. Normal UI must not briefly display stale direct results under a subtree hint or vice versa.

Gate: production-widget scroll and layout tests prove release back to the natural toolbar location below the cards, with no overlap/gap/jump. A browser diagram is not evidence.

## Phase F. Split-action picker and system Back

Adapt the shared picker content, not separate anchor/modal versions. Preserve frozen request/action handling, transactional mutation outcomes and Recent. Add two independent row targets with the specified trailing 80-pixel region, including leaf navigation and current-group selection. Use existing Kurumi feedback and localization.

Wire Back through the actual presenter/overlay owner. One owned Back event moves up one parent or dismisses at Home. Test Android system button and gesture dispatch, Escape and visible Back; no custom swipe handler. Child dialogs/IME keep first ownership where appropriate. Cancelled predictive Back must not navigate. Ensure an anchor does not close or pop its viewer on a nested Back.

Run the real Post/saved-record/Pool/Related and batch picker entry paths, including recent rows and sync-target selection. The left region only performs the caller's direct action; the right region never performs it. Keep Back left, Add Group right, and no additional bottom Back row. The primary screen's stored view mode does not affect picker navigation.

Gate: hit-boundary, narrow/enlarged, disabled/in-flight, lifecycle, stale/deleted target, creation cancellation, Recent and route-ownership tests pass for both presenters.

## Phase G. Verification and independent review

New tests may be split along these suggested responsibilities (new filenames, not claimed existing):

- `test/core/bookmarks/bookmark_group_hierarchy_test.dart`
- `test/core/bookmarks/bookmark_hierarchy_migration_test.dart`
- `test/core/bookmarks/bookmark_subtree_view_test.dart`
- `test/core/bookmarks/bookmark_hierarchy_mutations_test.dart`
- `test/core/bookmarks/bookmark_group_view_preferences_test.dart`
- `test/core/backups/bookmark_backup_v11_hierarchy_test.dart`
- `test/core/bookmarks/bookmark_hierarchy_scroll_test.dart`
- `test/core/bookmarks/bookmark_hierarchy_picker_test.dart`

Retain and adapt the existing `bookmark_folder_ux_test.dart`, `bookmark_group_browser_test.dart`, `bookmark_picker_lifecycle_test.dart`, `bookmark_saved_record_picker_test.dart`, `bookmark_all_membership_order_test.dart`, content search/index tests, relevant import/export tests and shared timeline tests. Preserve other folder consumers' regressions rather than deleting them with the Bookmark migration.

Use pinned FVM only. The #155 handoff reports Flutter 3.47.2 / Dart 3.13.2; do not upgrade dependencies/toolchain for this task. Use manual Riverpod providers, context.t, and existing generation policy. Run required generators only for changed inputs.

```bash
workers="$(python3 scripts/physical_core_count.py)"
# Format changed Dart files, then analyze affected scope or the full project.
fvm flutter test --no-pub "--concurrency=$workers" test/core/bookmarks test/core/backups test/core/groups
# Also run the exact affected application/content/timeline and package tests.
./scripts/run_regression_tests.sh
git diff --check
```

This is a shared-model/storage/UI change, so the final task candidate requires the complete local suite, not only a root Flutter pass. Compare performance using existing `benchmark/bookmark_mutation_latency_test.dart`, `bookmark_pipeline_performance_test.dart`, and relevant scalability workloads with their prescribed serial settings. Keep timing-independent unit tests and controlled fault injection; do not hide regressions by weakening assertions or removing roots.

### Android acceptance

Use Maestro on a properly leased Android emulator and back up/restore the existing environment. Prefer a disposable, isolated fixture database. Exercise actual normal application bootstrap and UI, not only the synthetic helper used for #155's native storage evidence.

1. Upgrade a legacy nested folder dataset and a real #155 v2 dataset separately; verify cold restart, group identities/placement, mixed records, exact dates, Related order and allocator continuity.
2. Open parent/child groups, both modes, title ancestor navigation and mode persistence after restart. Use duplicates in multiple children and a separately saved remote Work/Page pair when supported by the fixture/model.
3. Search direct bookmarks with nonmatching child names; verify the cards remain. Switch to subtree and verify scope, suggestions and deduplication. Confirm filtered-empty controls remain reachable.
4. Record the full scroll cycle through the subgroup boundary at narrow width and enlarged text, including chip wrap/keyboard and Back from a member viewer.
5. Exercise anchored and modal split targets, empty child creation, current-group save/remove, system Back at multiple depths, and root dismissal without popping the owning viewer.
6. Recheck safe Favorites Sync assignment to a nested group and direct-only membership mutation using controlled existing scenarios, without adding mirror sync or unapproved remote writes.

For production storage/codec tests record exact candidate, fixtures, fresh completion and hashes; for UI record normal boot, input actions and visible results. Separate host tests, native helper tests and actual UI evidence. Never claim one proves the others. Keep credentials/private payloads out of logs and commits.

### Delegation and review

The lead owns schema/versioning, collision mapping, durability/recovery, mutation semantics and scroll/presenter integration. Lower-cost subagents may implement bounded fixtures, translations, fixed mechanical consumers and independent test cases after the contract is frozen. Give disjoint file ownership or isolated worktrees; do not run competing storage/migration edits.

The final reviewer must be a fresh **Astra High** agent who did not author the canonical implementation/tests/fixes. Supply base SHA, final SHA, this specification, the live issue, exact test evidence, #155 inherited limits, and the whole delta. Require adversarial review of migration/ID preservation, aggregate remove/Undo, picker Back ownership and floating-boundary geometry. Sol High can review bounded intermediate work, but does not replace this final gate. If the exact reviewer capability is unavailable, report the review pending rather than silently downgrade or self-approve.

Fix findings in scope, rerun required checks and obtain independent re-review of the corrected candidate. Record model/effort and exact reviewed SHA truthfully. No minimum duration or unsupported review-count claims.

## Phase H. Continue the original plan

Update durable Bookmark/backup/UI documentation for the actual implementation and write an English #158 completion handoff with base/head, migration paths, checks, review evidence and pending limits. Preserve #155's historical evidence. Commit coherent work with `Refs #158`; do not wait until the end to save all progress.

After the required #158 gates pass, continue the existing rollout at #142 on a dependent issue branch carrying the verified #158 candidate, then #143, #156, #140, #141 and #157. Never restart those stages from an old #155-only or develop base and thereby lose the new hierarchy. Adapt their obsolete folder/v10 assumptions, without adding their implementation to #158. Do not ask again for permission to continue an already authorized stage; stop only for a real blocker, new material product decision or a missing separate authorization.

No PR, develop integration/push, runtime publication, issue closure or release is authorized by publishing these plans. The local agent must respect any additional explicit authorization already received, but not infer it from this documentation branch. The later final combined candidate still needs full regression and independent Astra High cross-stage review.
