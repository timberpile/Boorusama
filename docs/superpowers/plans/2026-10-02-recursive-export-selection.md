# Recursive Export Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flat export and recommendation lists with one arbitrary-depth selection hierarchy while preserving pinned-search folders, profile context, current `.bsexport` compatibility, and safe no-op import behavior.

**Architecture:** Add a recursive presentation descriptor above the existing flat stable-ID manifest selection. Source adapters translate selected folder/search IDs into payload scopes, while the export and import UIs render the same recursive nodes with source-specific labels and trailing profile metadata. Keep domain storage flat for now and retain existing import transaction semantics.

**Tech Stack:** Flutter, Dart, Riverpod Notifier/AsyncNotifier, Kurumi settings widgets, Equatable, Slang i18n, Flutter widget/unit tests, Maestro Android validation.

**Spec:** `docs/superpowers/specs/2026-10-02-recursive-export-selection-design.md`

## Global Constraints

- Use stable source, folder, group, search, feed, and profile IDs; do not encode display names into selections.
- Preserve `.bsexport` manifest compatibility and existing saved template JSON.
- A selected container ID means its live subtree; explicitly selected descendants mean only those IDs.
- Keep current domain storage flat; this change only makes the presentation and selection model recursive.
- Reject loose legacy JSON, but retain supported legacy archive imports.
- Do not add import undo, import history, or retained successful rollback data.
- All user-facing text must use `context.t`; regenerate i18n with `./gen.sh`.

## Review Focus

- Empty folders and stale folder membership must not crash the tree or export missing searches; pin this in Task 2 filtering tests.
- Equal search/feed names from different profiles must remain distinguishable; pin this in Task 3 widget tests.
- A saved folder selection must include later descendants while explicit search selections remain fixed; pin this in Tasks 1 and 2.
- Imported items absent from a presentation tree must remain reviewable through a safe flat fallback; pin this in Task 4 widget tests.
- Warnings on a no-op plan may be informational, while real validation errors must still block; pin both cases in Task 5 preflight/page tests.

---

### Task 1: Recursive selection model

**Files:**
- Modify: `lib/core/backups/export_import/models/export_selection.dart`
- Create: `lib/core/backups/export_import/models/export_item_presentation.dart`
- Modify: `lib/core/backups/export_import/export/export_flow_notifier.dart`
- Test: `test/core/backups/export_import/export_selection_test.dart`

**Interfaces:**
- Produces: `ExportSelectionNode({required String id, List<ExportSelectionNode> children = const []})` with recursive lookup/descendant helpers.
- Produces: `ExportSelectionDescriptor.collection({required String id, required List<ExportSelectionNode> children})`; `childIds` remains a flattened compatibility getter.
- Produces: `ExportItemPresentation({required String label, String? trailingLabel})` and `ExportSelectionPresentation.items` keyed by stable node ID.
- Produces: `ExportFlowNotifier.toggleNode(ExportSelectionDescriptor descriptor, ExportSelectionNode node)`.

- [ ] **Step 1: Write failing recursive selection tests**

Add tests proving that a four-level descriptor flattens every stable ID, finds a nested node, expands a selected folder to its current descendants, and keeps explicit leaves distinct from the folder ID. Add a template JSON round-trip assertion using nested-node IDs to prove the serialized selection format is unchanged.

- [ ] **Step 2: Run the model tests and verify RED**

Run: `fvm flutter test --no-pub test/core/backups/export_import/export_selection_test.dart`

Expected: FAIL because `ExportSelectionNode` and recursive descriptor APIs do not exist.

- [ ] **Step 3: Implement the recursive model and generic node toggle**

Keep `ExportNodeSelection.toJson/fromJson` unchanged. Implement recursive descriptor helpers and update `toggleNode` so selecting a container stores its ID and clears selected descendants, while deselecting a checked/partial container removes its ID and every descendant ID.

- [ ] **Step 4: Run the model tests and verify GREEN**

Run: `fvm flutter test --no-pub test/core/backups/export_import/export_selection_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/backups/export_import/models/export_selection.dart lib/core/backups/export_import/models/export_item_presentation.dart lib/core/backups/export_import/export/export_flow_notifier.dart test/core/backups/export_import/export_selection_test.dart
git commit -m "refactor(backups): add recursive export selection model"
```

### Task 2: Pinned-search hierarchy and payload preservation

**Files:**
- Modify: `lib/core/backups/sources/providers.dart`
- Modify: `lib/core/backups/export_import/sources/export_selection_ids.dart`
- Modify: `lib/core/backups/sources/pinned_search_backup_data.dart`
- Modify: `lib/core/backups/export_import/import/import_source_integrity_validator.dart`
- Modify: `lib/core/backups/export_import/export/export_flow_notifier.dart`
- Test: `test/core/backups/export_import/export_service_test.dart`
- Test: `test/core/backups/export_import/import_source_integrity_validator_test.dart`

**Interfaces:**
- Consumes: recursive descriptors and item presentation values from Task 1.
- Produces: `ExportSelectionIds.pinnedSearchHome` as the virtual Home subtree ID.
- Produces: `PinnedSearchExportScope.selected({required Iterable<String> searchIds, required Iterable<String> folderIds, required bool includeHome})`.
- Produces: live descriptors ordered as folder/Home containers with search leaves, plus profile trailing labels for search and feed leaves.

- [ ] **Step 1: Write failing scope and integrity tests**

Cover: selecting one search inside a folder emits that folder shell with only that search; selecting the folder ID emits all current members; selecting Home emits all current Home searches; explicit Home searches remain fixed; missing/stale member IDs are ignored; integrity validation accepts structural folder shells and the virtual Home ID without accepting unrelated payload records.

- [ ] **Step 2: Run focused data tests and verify RED**

Run: `fvm flutter test --no-pub test/core/backups/export_import/export_service_test.dart test/core/backups/export_import/import_source_integrity_validator_test.dart`

Expected: FAIL because current filters discard the folder for a search subset and have no Home selection.

- [ ] **Step 3: Build recursive live descriptors and filter scopes**

Create folder nodes from `SearchOrganization.folders`, a nonempty Home node from `homeSearchIds`, and search leaves only for non-feed-internal searches. Resolve profile IDs through `booruConfigProvider` for trailing labels. Update filtering and integrity rules to distinguish selected containers, selected leaves, and structural ancestors.

- [ ] **Step 4: Run focused data tests and verify GREEN**

Run the Task 2 command again.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/backups/sources/providers.dart lib/core/backups/export_import/sources/export_selection_ids.dart lib/core/backups/sources/pinned_search_backup_data.dart lib/core/backups/export_import/import/import_source_integrity_validator.dart lib/core/backups/export_import/export/export_flow_notifier.dart test/core/backups/export_import/export_service_test.dart test/core/backups/export_import/import_source_integrity_validator_test.dart
git commit -m "feat(backups): preserve pinned search hierarchy"
```

### Task 3: Recursive export selector UI

**Files:**
- Modify: `lib/core/backups/export_import/widgets/selection_tree.dart`
- Modify: `lib/core/backups/export_import/export/export_flow_page.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/backups/export_import/export_flow_page_test.dart`

**Interfaces:**
- Consumes: `ExportSelectionNode`, `ExportSelectionPresentation`, and `toggleNode` from Tasks 1-2.
- Produces: recursive `ExportSelectionTree` rendering any depth with separate checkbox and expansion semantics.
- Produces: trailing profile text using `Theme.of(context).colorScheme.onSurfaceVariant` and right alignment.

- [ ] **Step 1: Write failing recursive widget tests**

Use a four-level synthetic tree to assert nested expansion, child indentation, partial counts, `All current`, and `All, including future items`. Add equal-name search and feed rows with different trailing profile labels. Assert a leaf has no expansion semantics.

- [ ] **Step 2: Run the selector widget tests and verify RED**

Run: `fvm flutter test --no-pub test/core/backups/export_import/export_flow_page_test.dart`

Expected: FAIL because `ExportSelectionTree` only renders one child level and has no trailing metadata.

- [ ] **Step 3: Implement recursive rendering**

Render leaf nodes as checkbox tiles and containers as expansion tiles with a separate tristate checkbox. Derive each container state from its own selected ID and recursively selected descendants. Keep source-level full/current/partial semantics and make profile text visually secondary.

- [ ] **Step 4: Run the selector widget tests and verify GREEN**

Run the Task 3 command again.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/backups/export_import/widgets/selection_tree.dart lib/core/backups/export_import/export/export_flow_page.dart packages/i18n/translations/en-US.json test/core/backups/export_import/export_flow_page_test.dart
git commit -m "feat(backups): render recursive export selections"
```

### Task 4: Hierarchical recommendation and import action editors

**Files:**
- Create: `lib/core/backups/export_import/widgets/import_recommendation_tree.dart`
- Modify: `lib/core/backups/export_import/export/export_flow_page.dart`
- Modify: `lib/core/backups/export_import/widgets/import_action_editor.dart`
- Modify: `lib/core/backups/export_import/import/import_item_labels.dart`
- Modify: `lib/core/backups/export_import/import/import_flow_notifier.dart`
- Modify: `lib/core/backups/export_import/import/import_flow_page.dart`
- Test: `test/core/backups/export_import/export_flow_page_test.dart`
- Test: `test/core/backups/export_import/import_item_labels_test.dart`
- Test: `test/core/backups/export_import/import_flow_page_test.dart`

**Interfaces:**
- Consumes: recursive descriptors and `ExportItemPresentation` from Task 1.
- Produces: `ImportItemPresentationResult importItemPresentation(String sourceId, Object? data)`, containing a source descriptor and presentations derived from prepared incoming data.
- Produces: `ImportActionEditor.itemTree` and `itemPresentation` inputs, with unmatched proposed items appended as flat fallback leaves.
- Produces: sender recommendation tree filtered to nodes included by the current selection, including current descendants of dynamically selected containers.

- [ ] **Step 1: Write failing hierarchy tests**

Assert that sender recommendations initially show collapsed categories/folders, reveal only selected descendants when expanded, retain standard Kurumi selectors, and show profile labels. Assert receiver item actions use the incoming folder tree. Add an unknown proposed item and assert it remains visible through a fallback row.

- [ ] **Step 2: Run focused recommendation/import tests and verify RED**

Run: `fvm flutter test --no-pub test/core/backups/export_import/export_flow_page_test.dart test/core/backups/export_import/import_item_labels_test.dart test/core/backups/export_import/import_flow_page_test.dart`

Expected: FAIL because both editors are flat and incoming data supplies labels only.

- [ ] **Step 3: Implement shared hierarchical presentation**

Build descriptors from incoming profiles, bookmark groups, pinned-search folders/Home/searches, and feeds. Filter sender nodes by selection semantics, recursively render categories and folders, and keep item action updates keyed by the existing stable manifest item IDs. Preserve merge-target behavior.

- [ ] **Step 4: Run focused recommendation/import tests and verify GREEN**

Run the Task 4 command again.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/backups/export_import/widgets/import_recommendation_tree.dart lib/core/backups/export_import/export/export_flow_page.dart lib/core/backups/export_import/widgets/import_action_editor.dart lib/core/backups/export_import/import/import_item_labels.dart lib/core/backups/export_import/import/import_flow_notifier.dart lib/core/backups/export_import/import/import_flow_page.dart test/core/backups/export_import/export_flow_page_test.dart test/core/backups/export_import/import_item_labels_test.dart test/core/backups/export_import/import_flow_page_test.dart
git commit -m "feat(backups): group import recommendations"
```

### Task 5: Template, legacy JSON, and no-op review behavior

**Files:**
- Modify: `lib/core/backups/export_import/export/export_flow_page.dart`
- Modify: `lib/core/backups/export_import/import/legacy_import_stager.dart`
- Modify: `lib/core/backups/export_import/import/import_preflight.dart`
- Modify: `lib/core/backups/export_import/import/import_flow_page.dart`
- Modify: `packages/i18n/translations/en-US.json`
- Test: `test/core/backups/export_import/export_flow_page_test.dart`
- Test: `test/core/backups/export_import/legacy_import_stager_test.dart`
- Test: `test/core/backups/export_import/import_preflight_test.dart`
- Test: `test/core/backups/export_import/import_flow_page_test.dart`

**Interfaces:**
- Produces: `PlannedChangeSummary.hasMutations` as the shared no-op predicate.
- Preserves: legacy ZIP conversion and `.bsexport` package staging.

- [ ] **Step 1: Write failing behavior tests**

Assert the template dialog title is `Save as template`, exposes only `Cancel` and `Save`, and returns to the configuration after saving. Replace the loose-JSON conversion test with rejection. Add preflight/page tests proving a warning-only no-op is valid without acknowledgement, renders `Nothing to import`, and shows no empty `Problems to resolve`; add a real-error no-op case that remains blocked.

- [ ] **Step 2: Run focused behavior tests and verify RED**

Run: `fvm flutter test --no-pub test/core/backups/export_import/export_flow_page_test.dart test/core/backups/export_import/legacy_import_stager_test.dart test/core/backups/export_import/import_preflight_test.dart test/core/backups/export_import/import_flow_page_test.dart`

Expected: FAIL on the three-action dialog, JSON conversion, and warning acknowledgement/no-op behavior.

- [ ] **Step 3: Implement the approved behavior**

Return only a trimmed template name from the dialog and remove automatic export from template saving. Remove only the `.json` conversion path from `LegacyImportStager`. Gate warning acknowledgement on `summary.hasMutations`, compute visible errors without `warnings_not_acknowledged`, and use the same predicate in the review and completion UI.

- [ ] **Step 4: Regenerate translations and format changed Dart files**

Run: `./gen.sh`

Run: `fvm dart format lib/core/backups/export_import lib/core/backups/sources test/core/backups/export_import`

- [ ] **Step 5: Run focused behavior tests and verify GREEN**

Run the Task 5 test command again.

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/backups/export_import lib/core/backups/sources packages/i18n/translations/en-US.json test/core/backups/export_import
git commit -m "fix(backups): simplify template and no-op imports"
```

### Task 6: Integration verification and task completion

**Files:**
- Modify: `docs/work/in-progress/DATA-003-recursive-export-selection.md`
- Move after verification: `docs/work/in-progress/DATA-003-recursive-export-selection.md` to `docs/work/done/DATA-003-recursive-export-selection.md`

**Interfaces:**
- Consumes: completed Tasks 1-5.
- Produces: recorded automated and Android evidence with no remote publication.

- [ ] **Step 1: Run focused analysis and tests**

Run: `fvm flutter analyze --no-pub lib/core/backups/export_import lib/core/backups/sources test/core/backups/export_import`

Run: `fvm flutter test --no-pub test/core/backups/export_import`

Expected: no analysis issues and all focused tests pass.

- [ ] **Step 2: Run the complete test suite**

Run: `fvm flutter test --no-pub`

Expected: all tests pass; if unrelated timing failures recur, report them by exact test and rerun the complete failing file in isolation before classifying them.

- [ ] **Step 3: Validate Android UI with Maestro**

Build/install the Dev APK, obtain a device ID from Maestro, and exercise Custom export. Verify nested pinned-search expansion, partial/current/dynamic selection labels, right-aligned profile context, hierarchical recommendations, template save return, and a no-op import with warnings if a safe fixture is available. Record any unavailable data-dependent scenario explicitly.

- [ ] **Step 4: Record evidence and close the queue task**

Update every acceptance criterion and add exact commands/results and limitations. Move the stable task filename to `docs/work/done/` only after the evidence supports completion.

- [ ] **Step 5: Verify the final branch and commit**

Run: `git diff --check`

Run: `git rev-list --min-parents=2 origin/develop..HEAD`

Expected: no whitespace errors and no merge commits in the outgoing feature range.

```bash
git add docs/work/done/DATA-003-recursive-export-selection.md
git commit -m "docs(backups): record recursive selection completion"
```
